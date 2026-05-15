# Integration with Makie's `text` recipe via the AbstractTextPrimitive
# extension hook (added in Makie 0.25). Allows MakieTeX to feed real LaTeX
# directly into `text()`, Axis labels, ticks, titles, etc.
#
# See companion PR: https://github.com/MakieOrg/Makie.jl/pull/5632

"""
    TeXString(s)

A wrapper `AbstractString` that flags content for full-LaTeX rendering via
MakieTeX when passed through `text()`. Unlike `LaTeXString` (which uses
MathTeXEngine for in-process glyph layout), a `TeXString` is compiled with a
real LaTeX engine and embedded into the text plot as a single image primitive.
It Just Works™ everywhere `text()` is used: `text!()` calls, Axis `title`,
`xlabel`, `ylabel`, `xtickformat` returning a `Vector{TeXString}`, etc.
"""
struct TeXString <: AbstractString
    s::String
end
TeXString(s::AbstractString) = TeXString(String(s))
TeXString(l::LaTeXString) = TeXString(String(l))

# Forward the AbstractString interface to the wrapped String.
Base.ncodeunits(t::TeXString) = ncodeunits(t.s)
Base.codeunit(t::TeXString) = codeunit(t.s)
Base.codeunit(t::TeXString, i::Integer) = codeunit(t.s, i)
Base.iterate(t::TeXString) = iterate(t.s)
Base.iterate(t::TeXString, i::Integer) = iterate(t.s, i)
Base.isvalid(t::TeXString, i::Integer) = isvalid(t.s, i)
Base.String(t::TeXString) = t.s
Base.convert(::Type{String}, t::TeXString) = t.s

# A TeXString never counts as whitespace for layout purposes — Axis label
# layout checks `iswhitespace` to decide whether to reserve space for the label.
Makie.iswhitespace(::TeXString) = false

# Scatter centers its marker on the position, then adds `marker_offset`. To
# make `position` correspond to the alignment edge of the marker, shift by
# half the marker size scaled by the alignment fraction. `valign === :baseline`
# is supported: `baseline_from_bottom` is the descender depth in markerspace.
function _texstring_align_offset(align::Tuple, wh::Makie.Vec2f, baseline_from_bottom::Real = 0.0f0)
    halign, valign = align
    fhalign = halign === :left ? 0.0f0 :
        halign === :center ? 0.5f0 :
        halign === :right ? 1.0f0 : Float32(halign)
    ox = (0.5f0 - fhalign) * wh[1]
    oy = if valign === :baseline
        0.5f0 * wh[2] - Float32(baseline_from_bottom)
    else
        fvalign = valign === :bottom ? 0.0f0 :
            valign === :center ? 0.5f0 :
            valign === :top ? 1.0f0 : Float32(valign)
        (0.5f0 - fvalign) * wh[2]
    end
    return Makie.Vec2f(ox, oy)
end

# Safety margin (pt) added on all four sides of the cropped PDF so the
# rasterizer doesn't clip anti-aliased glyph edges at the bbox boundary.
# Tracked in the returned tuple so all alignment / bbox math can subtract it
# off and reason about the natural ink box rather than the padded marker.
const _TEX_CROP_MARGIN_PT = 1.0f0

"""
    compile_texstring(latex_src::AbstractString) -> (cached::CachedPDF, baseline_pt::Float32, margin_pt::Float32)

Compile a `TeXString` payload to a `CachedPDF` and simultaneously extract the
descender depth (`\\dp`) of the rendered box — needed for
`align = (:left, :baseline)`. Single LaTeX run: the content is wrapped in
`\\sbox` + `\\typeout`, then `\\usebox`'d, so the same compile produces both the
PDF that gets rendered and a log line we parse back for the baseline.

The returned `cached` document is cropped with a small symmetric pt margin
to avoid clipping anti-aliased glyph edges at the bbox boundary; `margin_pt`
is that margin (per side) so callers can recover the natural ink box.
"""
function compile_texstring(latex_src::AbstractString)
    src = String(latex_src)
    body = """
    \\newsavebox\\makietexbaselinebox%
    \\sbox\\makietexbaselinebox{$(src)}%
    \\typeout{MAKIETEX_BASELINE_DEPTH=\\the\\dp\\makietexbaselinebox}%
    \\usebox\\makietexbaselinebox
    """
    doc = implant_text(body)
    pdf, baseline_pt = _compile_latex_capture_baseline(String(doc.contents))
    # `CachedTEX(::Vector{UInt8})` is broken upstream (it stashes `nothing`
    # into a strictly-typed `doc::TEXDocument` field). `CachedPDF` works fine
    # and is what `page2img` dispatches on anyway.
    cached = CachedPDF(PDFDocument(pdf))
    return cached, baseline_pt, _TEX_CROP_MARGIN_PT
end

# Mirror of MakieTeX.compile_latex's tempdir-and-latexmk pipeline, but also
# reads `temp.log` before the directory is torn down and pulls the baseline
# depth out of it. Returns the cropped PDF as `Vector{UInt8}` plus the depth
# in pt.
function _compile_latex_capture_baseline(document::String)
    return mktempdir() do dir
        cd(dir) do
            write("temp.tex", document)
            out = Pipe(); err = Pipe()
            try
                cmd = if CURRENT_TEX_ENGINE[] == `tectonic`
                    `$(tectonic_jll.tectonic()) temp.tex`
                else
                    `latexmk -file-line-error --shell-escape -cd -$(CURRENT_TEX_ENGINE[]) -interaction=nonstopmode temp.tex`
                end
                run(pipeline(ignorestatus(cmd), stdout = out, stderr = err))
            finally
                close(out.in); close(err.in)
            end
            log_text = isfile("temp.log") ? read("temp.log", String) : ""
            m = match(r"MAKIETEX_BASELINE_DEPTH=([-0-9.]+)pt", log_text)
            baseline_pt = m === nothing ? 0.0f0 : max(0.0f0, parse(Float32, m.captures[1]))
            # Symmetric safety margin: Ghostscript's `bbox` device returns
            # integer-pt-truncated bounds, so anti-aliased glyph edges right
            # at the bbox boundary can otherwise get clipped by the
            # rasterizer. Callers subtract the margin out for alignment.
            m = _TEX_CROP_MARGIN_PT
            pdf = crop_pdf("temp.pdf"; margin = (m, m, m, m))
            return Vector{UInt8}(pdf), baseline_pt
        end
    end
end

# LaTeX's default base font is 12pt; we scale the rendered PDF's pt dims so
# that fontsize=12 in Makie ≈ 12pt rendered output.
const _TEXSTRING_BASE_PT = 12.0f0

function Makie.convert_text_string!(
        outputs::NamedTuple, input_text::TeXString,
        i, N, fontsize, font, align, rotation, justification,
        lineheight, word_wrap_width, offset, fonts, color, strokecolor, strokewidth
    )

    fs = Float32(Makie.sv_getindex(fontsize, i))
    al = Makie.sv_getindex(align, i)
    rot = convert(Makie.Quaternionf, Makie.sv_getindex(rotation, i))
    off = Makie.Vec3f(Makie.sv_getindex(offset, i))

    # Single LaTeX compile: yields both the rendered PDF (used to build a
    # CachedPDF → rasterized marker image) and the box-depth in pt for
    # `align = (..., :baseline)`. `page2img` is called directly because
    # `rasterize(::CachedTEX)` ignores its `scale` arg for TEX.
    cached, baseline_pt, margin_pt = compile_texstring(input_text.s)
    density = max(2, ceil(Int, Float64(fs) / _TEXSTRING_BASE_PT) * 4)
    img = page2img(cached, cached.doc.page; render_density = density)

    # `dim_pt` includes a `margin_pt` safety pad on each side (added at crop
    # time to keep anti-aliased glyphs from clipping). The natural ink box
    # is `dim_pt - 2 * margin_pt`. Alignment refers to the ink box so the
    # safety pad doesn't shift positions.
    scale = fs / _TEXSTRING_BASE_PT
    dim_pt = Makie.Vec2f(Float32(cached.dims[1]), Float32(cached.dims[2]))
    target_size = dim_pt .* scale
    ink_size = (dim_pt .- 2 * margin_pt) .* scale
    baseline_from_bottom = baseline_pt * scale

    align_off = _texstring_align_offset(al, ink_size, baseline_from_bottom)
    marker_offset = Makie.Vec3f(align_off[1], align_off[2], 0) + off

    # `text_blocks` must have one entry per input string. This block has no
    # glyphs — only an image primitive — so we push an empty range.
    curr = length(outputs.glyphindices)
    push!(outputs.text_blocks, (curr + 1):curr)
    push!(
        outputs.glyphcollections, Makie.GlyphCollection(
            UInt64[], Makie.NativeFont[], Makie.Point3f[], Makie.GlyphExtent[],
            Makie.Vec2f[], Makie.Quaternionf[], Makie.RGBAf[], Makie.RGBAf[], Float32[]
        )
    )

    push!(outputs.text_primitives, Makie.ImageTextPrimitive(img, marker_offset, target_size, rot))
    push!(outputs.text_primitive_block_indices, i)
    return
end
