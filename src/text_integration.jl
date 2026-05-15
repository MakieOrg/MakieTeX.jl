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

"""
    detect_tex_baseline(latex_src::AbstractString) -> Float32

Return the descender depth (in pt) of the rendered LaTeX — i.e. how far the
content extends below its baseline. Used to support `align = (:left, :baseline)`.

LaTeX is asked to measure the rendered box and `\\typeout` its `\\dp` (depth)
into the run log; the log is then parsed back. One compile, no rendering of
visible markers, no interference from MakieTeX's PDF cropping step.
"""
function detect_tex_baseline(latex_src::AbstractString)
    src = String(latex_src)
    body = """
    \\newsavebox\\makietexbaselinebox%
    \\sbox\\makietexbaselinebox{$(src)}%
    \\typeout{MAKIETEX_BASELINE_DEPTH=\\the\\dp\\makietexbaselinebox}%
    \\usebox\\makietexbaselinebox
    """
    doc = implant_text(body)
    return _compile_and_parse_baseline(String(doc.contents))
end

function _compile_and_parse_baseline(document::String)
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
            m === nothing && return 0.0f0
            return max(0.0f0, parse(Float32, m.captures[1]))
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

    # Compile LaTeX → cached PDF → rasterized image. Bypass MakieTeX's
    # `rasterize(::CachedTEX)` because it ignores the `scale` arg for TEX;
    # `page2img` honors `render_density` directly.
    cached = CachedTEX(input_text.s)
    density = max(2, ceil(Int, Float64(fs) / _TEXSTRING_BASE_PT) * 4)
    img = page2img(cached, cached.doc.page; render_density = density)

    dim_pt = Makie.Vec2f(Float32(cached.dims[1]), Float32(cached.dims[2]))
    target_size = dim_pt .* (fs / _TEXSTRING_BASE_PT)

    # When valign=:baseline, do a second compile with a depth probe to measure
    # the content's descender. Skipped otherwise — keeps the common path cheap.
    baseline_from_bottom = if al[2] === :baseline
        descender_pt = detect_tex_baseline(input_text.s)
        descender_pt * (fs / _TEXSTRING_BASE_PT)
    else
        0.0f0
    end

    align_off = _texstring_align_offset(al, target_size, baseline_from_bottom)
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
