# Integration with Makie's `text` recipe via the `AbstractTextPrimitive` +
# `latex_handler` extension hooks (added in Makie 0.25). Lets MakieTeX
# render any `LaTeXString` passed into `text()` (and therefore Axis labels,
# titles, tick labels via `xtickformat`, etc.) with a real LaTeX engine
# instead of MathTeXEngine's in-process glyph approximation.
#
# Usage:
#
#   set_theme!(latex_handler = MakieTeXLaTeX())                       # global default
#   with_theme(latex_handler = MakieTeXLaTeX(preamble = "…")) do … end # scoped override
#   text!(scene, L"…"; latex_handler = MakieTeXLaTeX(preamble = "…"))  # per-plot override
#
# Each `MakieTeXLaTeX` value carries its own preamble / class options /
# engine, so different text plots in the same figure can compile against
# different LaTeX setups (e.g. one Axis using `physics` package macros and
# another using `siunitx`).
#
# Without a handler set, Makie's default MathTeXEngine path is used — good
# for quick iteration; switch to MakieTeXLaTeX to polish a publication-
# quality figure without changing plot code (especially useful when the
# LaTeXStrings come from a third-party plotting function you don't control).
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

const _DEFAULT_PREAMBLE = "\\usepackage{amsmath, amsfonts, xcolor}\n\\pagestyle{empty}\n\\nopagecolor"
const _DEFAULT_CLASSOPTIONS = "preview, tightpage, 12pt"

"""
    MakieTeXLaTeX(; preamble, classoptions, engine, border_pt,
                    crop_margin_pt, base_pt)

A `latex_handler` for Makie's `text` recipe that renders `LaTeXString`
content with a real LaTeX engine (via MakieTeX). Construct one and pass it
to `set_theme!` / `with_theme` / a plot's `latex_handler` attribute.

# Fields

* `preamble` — LaTeX preamble (everything between `\\documentclass{…}` and
  `\\begin{document}`). Default loads `amsmath, amsfonts, xcolor` and sets
  `\\pagestyle{empty}\\nopagecolor` so the page background is transparent.
* `classoptions` — options to the standalone class (without `border=`, that
  field is appended automatically from `border_pt`). Default
  `"preview, tightpage, 12pt"`.
* `engine` — `nothing` (use `MakieTeX.CURRENT_TEX_ENGINE[]`) or a `Cmd` like
  `` `lualatex` `` / `` `pdflatex` `` / `` `tectonic` ``.
* `border_pt` — pt margin built into the standalone page MediaBox; must be
  larger than `crop_margin_pt` so the safety crop below has room to extend.
* `crop_margin_pt` — symmetric pt safety pad cropped around the ink, so
  anti-aliased glyph edges aren't clipped by the page boundary.
* `base_pt` — LaTeX font size assumed in the document (Makie's `fontsize`
  is scaled by `fontsize / base_pt`).
"""
Base.@kwdef struct MakieTeXLaTeX
    preamble::String = _DEFAULT_PREAMBLE
    classoptions::String = _DEFAULT_CLASSOPTIONS
    engine::Union{Nothing, Cmd} = nothing
    border_pt::Int = 3
    crop_margin_pt::Float32 = 2.0f0
    base_pt::Float32 = 12.0f0
end

"""
    compile_latex_for_makie(h::MakieTeXLaTeX, latex_src::AbstractString)
        -> (cached::CachedPDF, baseline_pt::Float32)

Compile a LaTeX snippet under the configuration `h` to a `CachedPDF` and
simultaneously extract the descender depth (`\\dp`) of the rendered box —
needed for `align = (:left, :baseline)`. Single LaTeX run: the content is
wrapped in `\\sbox` + `\\typeout`, then `\\usebox`'d, so the same compile
produces both the PDF that gets rendered and a log line we parse back for
the baseline. The returned `cached` document is cropped with a symmetric
`h.crop_margin_pt` margin to avoid clipping anti-aliased glyph edges.
"""
function compile_latex_for_makie(h::MakieTeXLaTeX, latex_src::AbstractString)
    src = String(latex_src)
    body = """
    \\newsavebox\\makietexbaselinebox%
    \\sbox\\makietexbaselinebox{$(src)}%
    \\typeout{MAKIETEX_BASELINE_DEPTH=\\the\\dp\\makietexbaselinebox}%
    \\usebox\\makietexbaselinebox
    """
    # Build the TEXDocument ourselves so we can set `border=Npt` from the
    # handler config — gives the page MediaBox enough room for our crop
    # margin (otherwise the crop clamps to MediaBox and the margin
    # disappears in y).
    doc = TEXDocument(body, true;
        requires = "\\RequirePackage{luatex85}",
        preamble = h.preamble,
        class = "standalone",
        classoptions = "$(h.classoptions), border=$(h.border_pt)pt",
    )
    engine = h.engine === nothing ? CURRENT_TEX_ENGINE[] : h.engine
    pdf, baseline_pt = _compile_latex_capture_baseline(String(doc.contents), engine, h.crop_margin_pt)
    # `CachedTEX(::Vector{UInt8})` is broken upstream (it stashes `nothing`
    # into a strictly-typed `doc::TEXDocument` field). `CachedPDF` works
    # fine and is what `page2img` dispatches on anyway.
    return CachedPDF(PDFDocument(pdf)), baseline_pt
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
function _compile_latex_capture_baseline(document::String, engine::Cmd, crop_margin_pt::Real)
    return mktempdir() do dir
        cd(dir) do
            write("temp.tex", document)
            out = Pipe(); err = Pipe()
            try
                cmd = if engine == `tectonic`
                    `$(tectonic_jll.tectonic()) temp.tex`
                else
                    `latexmk -file-line-error --shell-escape -cd -$(engine) -interaction=nonstopmode temp.tex`
                end
                run(pipeline(ignorestatus(cmd), stdout = out, stderr = err))
            finally
                close(out.in); close(err.in)
            end
            log_text = isfile("temp.log") ? read("temp.log", String) : ""
            m = match(r"MAKIETEX_BASELINE_DEPTH=([-0-9.]+)pt", log_text)
            baseline_pt = m === nothing ? 0.0f0 : max(0.0f0, parse(Float32, m.captures[1]))
            pdf = _hires_crop_pdf("temp.pdf", crop_margin_pt)
            return pdf, baseline_pt
        end
    end
end

# Makie calls the handler as `h(outputs, latex_str, i, N, _inputs...)`. We
# make `MakieTeXLaTeX` callable with that exact signature.
function (h::MakieTeXLaTeX)(
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
    cached, baseline_pt = compile_latex_for_makie(h, String(latex_str))

    # `dim_pt` includes the safety pad `h.crop_margin_pt` on each side (added
    # at crop time to keep anti-aliased glyphs from clipping). The natural
    # ink box is `dim_pt - 2 * crop_margin_pt`. Alignment refers to the ink
    # box so the safety pad doesn't shift positions.
    scale = fs / h.base_pt
    dim_pt = Makie.Vec2f(Float32(cached.dims[1]), Float32(cached.dims[2]))
    target_size = dim_pt .* scale
    ink_size = (dim_pt .- 2 * h.crop_margin_pt) .* scale
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
