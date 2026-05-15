# Integration with Makie's `text` recipe via the `AbstractTextPrimitive` +
# `latex_handler` extension hooks (added in Makie 0.25). Lets MakieTeX
# render any `LaTeXString` passed into `text()` (and therefore Axis labels,
# titles, tick labels via `xtickformat`, etc.) with a real LaTeX engine
# instead of MathTeXEngine's in-process glyph approximation.
#
# Usage (one of):
#
#   set_theme!(latex_handler = MakieTeX.makietex_latex_handler)
#   with_theme(latex_handler = MakieTeX.makietex_latex_handler) do … end
#
# Without the handler set, Makie's default MathTeXEngine path is used — good
# for quick iteration; switch to this handler to polish a publication-quality
# figure without changing plot code (especially useful when LaTeXStrings come
# from a third-party plotting function you don't control).
#
# See companion PR: https://github.com/MakieOrg/Makie.jl/pull/5632

# Scatter centers its marker on the position, then adds `marker_offset`. To
# make `position` correspond to the alignment edge of the marker, shift by
# half the marker size scaled by the alignment fraction. `valign === :baseline`
# is supported: `baseline_from_bottom` is the descender depth in markerspace.
function _latex_align_offset(align::Tuple, wh::Makie.Vec2f, baseline_from_bottom::Real = 0.0f0)
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

# Safety margin (pt) of empty space on all four sides of the rendered marker
# image, so the rasterizer doesn't clip anti-aliased glyph edges and so the
# ink sits at a *known* distance from the page boundary (used by alignment).
# We need two things to make this work:
#   1. `classoptions` includes a `border` slightly larger than the margin, so
#      the page MediaBox has room to accommodate the cropped extension below
#      and above the ink (otherwise crop clamps to MediaBox and the margin
#      effectively disappears in y).
#   2. The crop uses `%%HiResBoundingBox` from Ghostscript with sub-pt
#      precision; `%%BoundingBox` rounds to ints and leaves up to 1pt of
#      jitter in ink position, which would propagate as a visible baseline
#      offset.
const _TEX_CROP_MARGIN_PT = 2.0f0
const _TEX_DOC_BORDER_PT  = 3   # > margin so MediaBox has room

# LaTeX's default base font is 12pt; we scale the rendered PDF's pt dims so
# that fontsize=12 in Makie ≈ 12pt rendered output.
const _LATEX_HANDLER_BASE_PT = 12.0f0

"""
    compile_latex_for_makie(latex_src::AbstractString) -> (cached::CachedPDF, baseline_pt::Float32, margin_pt::Float32)

Compile a LaTeX snippet to a `CachedPDF` and simultaneously extract the
descender depth (`\\dp`) of the rendered box — needed for
`align = (:left, :baseline)`. Single LaTeX run: the content is wrapped in
`\\sbox` + `\\typeout`, then `\\usebox`'d, so the same compile produces both
the PDF that gets rendered and a log line we parse back for the baseline.

The returned `cached` document is cropped with a small symmetric pt margin
to avoid clipping anti-aliased glyph edges at the bbox boundary; `margin_pt`
is that margin (per side) so callers can recover the natural ink box.
"""
function compile_latex_for_makie(latex_src::AbstractString)
    src = String(latex_src)
    body = """
    \\newsavebox\\makietexbaselinebox%
    \\sbox\\makietexbaselinebox{$(src)}%
    \\typeout{MAKIETEX_BASELINE_DEPTH=\\the\\dp\\makietexbaselinebox}%
    \\usebox\\makietexbaselinebox
    """
    # Build the TEXDocument ourselves so we can set `border=Npt` in the
    # standalone class options — this gives the page MediaBox enough room
    # for our crop margin.
    doc = TEXDocument(body, true;
        requires = "\\RequirePackage{luatex85}",
        preamble = "\\usepackage{amsmath, amsfonts, xcolor}\\pagestyle{empty}\\nopagecolor",
        class = "standalone",
        classoptions = "preview, tightpage, 12pt, border=$(_TEX_DOC_BORDER_PT)pt",
    )
    pdf, baseline_pt = _compile_latex_capture_baseline(String(doc.contents))
    # `CachedTEX(::Vector{UInt8})` is broken upstream (it stashes `nothing`
    # into a strictly-typed `doc::TEXDocument` field). `CachedPDF` works fine
    # and is what `page2img` dispatches on anyway.
    cached = CachedPDF(PDFDocument(pdf))
    return cached, baseline_pt, _TEX_CROP_MARGIN_PT
end

# Like MakieTeX's `crop_pdf`, but reads Ghostscript's `%%HiResBoundingBox`
# (sub-pt precision) rather than the integer `%%BoundingBox`. With the
# integer version, glyph edges can be jittered by up to ~1pt within the
# crop, which propagates into visible baseline misalignment.
function _hires_pdf_bbox(path::String)
    out = Pipe(); err = Pipe()
    success(pipeline(`$(Ghostscript_jll.gs()) -q -dBATCH -dNOPAUSE -sDEVICE=bbox $path`, stdout = out, stderr = err))
    close(out.in); close(err.in)
    result = read(err, String)
    m = match(r"%%HiResBoundingBox: ([-0-9.]+) ([-0-9.]+) ([-0-9.]+) ([-0-9.]+)", result)
    m === nothing && error("could not extract %%HiResBoundingBox from gs output")
    return parse.(Float64, (m.captures[1], m.captures[2], m.captures[3], m.captures[4]))
end

function _hires_crop_pdf(path::String, margin::Real)
    bb = _hires_pdf_bbox(path)
    crop_box = (bb[1] - margin, bb[2] - margin, bb[3] + margin, bb[4] + margin)
    crop_cmd = join(crop_box, " ")
    out_path = "_hires_cropped.pdf"
    out = Pipe(); err = Pipe()
    try
        redirect_stderr(err) do
            redirect_stdout(out) do
                Ghostscript_jll.gs() do gs_exe
                    run(`$gs_exe -o $out_path -sDEVICE=pdfwrite -c "[/CropBox [$crop_cmd]" -c "/PAGES pdfmark" -f $path`)
                end
            end
        end
    catch e
    finally
        close(out.in); close(err.in)
    end
    return read(out_path)
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
            pdf = _hires_crop_pdf("temp.pdf", _TEX_CROP_MARGIN_PT)
            return pdf, baseline_pt
        end
    end
end

"""
    makietex_latex_handler(outputs, latex_str, i, N, fontsize, font, align,
                           rotation, justification, lineheight, word_wrap_width,
                           offset, fonts, color, strokecolor, strokewidth)

`latex_handler` for Makie's `text` recipe. Renders `latex_str::LaTeXString`
with a real LaTeX engine (via MakieTeX) and embeds the result into the text
plot as a single image primitive — replacing Makie's default MathTeXEngine
glyph layout. Install it through theming:

    set_theme!(latex_handler = MakieTeX.makietex_latex_handler)

After that, every `L"…"` you (or anyone whose plotting code you call) hand
to `text()` / Axis labels / `xtickformat` etc. renders via lualatex /
pdflatex / tectonic.
"""
function makietex_latex_handler(
        outputs::NamedTuple, latex_str::LaTeXString,
        i, N, fontsize, font, align, rotation, justification,
        lineheight, word_wrap_width, offset, fonts, color, strokecolor, strokewidth
    )

    fs = Float32(Makie.sv_getindex(fontsize, i))
    al = Makie.sv_getindex(align, i)
    rot = convert(Makie.Quaternionf, Makie.sv_getindex(rotation, i))
    off = Makie.Vec3f(Makie.sv_getindex(offset, i))

    # Single LaTeX compile: yields the rendered PDF + the box-depth in pt for
    # `align = (..., :baseline)`. The `CachedPDF` is passed straight to scatter
    # as the marker — CairoMakie's `draw_marker(::CachedPDF, …)` override (in
    # MakieTeXCairoMakieExt) hands it to `poppler_page_render`, which puts
    # the PDF's vector content directly into the figure's Cairo surface (no
    # raster intermediate, so hairlines stay crisp).
    cached, baseline_pt, margin_pt = compile_latex_for_makie(String(latex_str))

    # `dim_pt` includes a `margin_pt` safety pad on each side (added at crop
    # time to keep anti-aliased glyphs from clipping). The natural ink box
    # is `dim_pt - 2 * margin_pt`. Alignment refers to the ink box so the
    # safety pad doesn't shift positions.
    scale = fs / _LATEX_HANDLER_BASE_PT
    dim_pt = Makie.Vec2f(Float32(cached.dims[1]), Float32(cached.dims[2]))
    target_size = dim_pt .* scale
    ink_size = (dim_pt .- 2 * margin_pt) .* scale
    baseline_from_bottom = baseline_pt * scale

    align_off = _latex_align_offset(al, ink_size, baseline_from_bottom)
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

    push!(outputs.text_primitives, Makie.ImageTextPrimitive(cached, marker_offset, target_size, rot))
    push!(outputs.text_primitive_block_indices, i)
    return
end
