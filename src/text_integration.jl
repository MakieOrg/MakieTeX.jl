# Integration with Makie's `text` recipe via the `text_handler` hook
# (Makie 0.25+). When `text_handler` is set to a `LaTeX`, any
# `LaTeXString` going through `text()` — including Axis labels, titles,
# tick labels — is rendered with a real LaTeX engine instead of
# MathTeXEngine. Other input types fall through.
# See https://github.com/MakieOrg/Makie.jl/pull/5632.

"""
    AbstractPdfTextHandler

Shared supertype for text handlers whose `compile_text` produces a
`(CachedPDF, baseline_pt)` tuple. `place_text!` is implemented once on this
supertype; concrete handlers only need to override `compile_text`.

[`AbstractLaTeX`](@ref) and `AbstractTypst` both subtype this.
"""
abstract type AbstractPdfTextHandler end

# Convert an `(halign, valign)` pair into a markerspace offset that maps
# scatter's center anchor onto the alignment edge. `:baseline` valign is
# supported via `baseline_from_bottom` (descender depth in markerspace).
function _pdf_align_offset(align::Tuple, wh::Makie.Vec2f, baseline_from_bottom::Real = 0.0f0)
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
const _DEFAULT_CLASSOPTIONS = "preview, tightpage"

"""
    AbstractLaTeX

Shared supertype for [`LaTeX`](@ref) (LaTeXString only) and
[`FullLaTeX`](@ref) (LaTeXString + plain strings).
"""
abstract type AbstractLaTeX <: AbstractPdfTextHandler end

"""
    LaTeX(; preamble, classoptions, engine, border_pt, crop_margin_pt)

A `text_handler` for Makie's `text` recipe that renders `LaTeXString` content
with a real LaTeX engine. Pass to `set_theme!` / `with_theme` / a plot's
`text_handler` attribute. Plain `String` inputs fall through to the default
FreeType glyph layout. Use [`FullLaTeX`](@ref) to also route plain
strings through LaTeX.

# Fields

* `preamble` — LaTeX preamble. Default loads `amsmath, amsfonts, xcolor` and
  sets a transparent page background.
* `classoptions` — `standalone` class options (without `border=`, which is
  appended from `border_pt`).
* `engine` — `nothing` (use `MakieTeX.CURRENT_TEX_ENGINE[]`) or a `Cmd`.
* `border_pt` — pt margin in the page MediaBox; must exceed `crop_margin_pt`.
* `crop_margin_pt` — safety pad around the ink so anti-aliased edges aren't
  clipped at the page boundary.
"""
Base.@kwdef struct LaTeX <: AbstractLaTeX
    preamble::String = _DEFAULT_PREAMBLE
    classoptions::String = _DEFAULT_CLASSOPTIONS
    engine::Union{Nothing, Cmd} = nothing
    border_pt::Int = 3
    crop_margin_pt::Float32 = 2.0f0
end

"""
    FullLaTeX(; preamble, classoptions, engine, border_pt, crop_margin_pt)

Like [`LaTeX`](@ref), but also routes plain `AbstractString` inputs
through LaTeX (with appropriate text-mode escaping for special characters).
Closest analogue to matplotlib's `rcParams["text.usetex"] = True`.
"""
Base.@kwdef struct FullLaTeX <: AbstractLaTeX
    preamble::String = _DEFAULT_PREAMBLE
    classoptions::String = _DEFAULT_CLASSOPTIONS
    engine::Union{Nothing, Cmd} = nothing
    border_pt::Int = 3
    crop_margin_pt::Float32 = 2.0f0
end

# Escape LaTeX special chars for text-mode embedding. `replace` with multiple
# pairs scans the source once and skips re-processing replacements, so the
# `{`/`}` in `\textbackslash{}` etc. don't get double-escaped.
function _escape_for_text_mode(s::AbstractString)
    return replace(
        s,
        '\\' => raw"\textbackslash{}",
        '{'  => raw"\{",
        '}'  => raw"\}",
        '$'  => raw"\$",
        '&'  => raw"\&",
        '#'  => raw"\#",
        '_'  => raw"\_",
        '%'  => raw"\%",
        '^'  => raw"\textasciicircum{}",
        '~'  => raw"\textasciitilde{}",
        '\n' => raw"\\",
    )
end

# Compile inputs (color, fontsize, lineheight) are baked into the LaTeX source
# so the resulting PDF is already correctly sized and colored. Inline LaTeX
# color/size commands override these in the natural way.
function _compile_latex_block(h::AbstractLaTeX, body::String, color, fontsize, lineheight)
    color_hex = Colors.hex(convert(RGB, Makie.to_color(color)))
    fs = Float32(fontsize)
    lh = Float32(lineheight)

    document = """
    \\RequirePackage{luatex85}
    \\documentclass[$(h.classoptions), border=$(h.border_pt)pt]{standalone}
    $(h.preamble)
    \\definecolor{maincolor}{HTML}{$(color_hex)}
    \\begin{document}
    \\newsavebox\\makietexbaselinebox%
    \\sbox\\makietexbaselinebox{%
    \\color{maincolor}\\fontsize{$(fs)pt}{$(fs * lh)pt}\\selectfont $(body)%
    }%
    \\typeout{MAKIETEX_BASELINE_DEPTH=\\the\\dp\\makietexbaselinebox}%
    \\usebox\\makietexbaselinebox
    \\end{document}
    """
    engine = h.engine === nothing ? CURRENT_TEX_ENGINE[] : h.engine
    pdf, baseline_pt = _compile_latex_capture_baseline(document, engine, h.crop_margin_pt)
    return (CachedPDF(PDFDocument(pdf)), baseline_pt)
end

# Both variants accept LaTeXString. Explicit methods on concrete types avoid
# the (Full, AbstractString) vs (Abstract, LaTeXString) ambiguity that would
# arise with a single LaTeXString method on the abstract supertype.
Makie.compile_text(h::LaTeX, src::LaTeXString, color, fontsize, lineheight) =
    _compile_latex_block(h, String(src), color, fontsize, lineheight)
Makie.compile_text(h::FullLaTeX, src::LaTeXString, color, fontsize, lineheight) =
    _compile_latex_block(h, String(src), color, fontsize, lineheight)

# Only the Full variant claims plain strings.
Makie.compile_text(h::FullLaTeX, src::AbstractString, color, fontsize, lineheight) =
    _compile_latex_block(h, _escape_for_text_mode(src), color, fontsize, lineheight)

function Makie.place_text!(
        h::AbstractPdfTextHandler, outputs::NamedTuple, i, N, compiled,
        fontsize, font, align, rotation, justification, lineheight,
        word_wrap_width, offset, fonts, color, strokecolor, strokewidth,
    )
    cached, baseline_pt = compiled
    al = Makie.sv_getindex(align, i)
    rot = convert(Makie.Quaternionf, Makie.sv_getindex(rotation, i))
    off = Makie.Vec3f(Makie.sv_getindex(offset, i))

    # The PDF is already at the correct fontsize; markersize is the literal
    # PDF dimensions. `crop_margin_pt` was padded around the ink at crop time,
    # so the natural ink box is `dim_pt - 2 * crop_margin_pt`.
    dim_pt = Makie.Vec2f(Float32(cached.dims[1]), Float32(cached.dims[2]))
    ink_size = dim_pt .- 2 * h.crop_margin_pt

    align_off = _pdf_align_offset(al, ink_size, baseline_pt)
    marker_offset = Makie.Vec3f(align_off[1], align_off[2], 0) + off

    curr = length(outputs.glyphindices)
    push!(outputs.text_blocks, (curr + 1):curr)
    push!(
        outputs.glyphcollections, Makie.GlyphCollection(
            UInt64[], Makie.NativeFont[], Makie.Point3f[], Makie.GlyphExtent[],
            Makie.Vec2f[], Makie.Quaternionf[], Makie.RGBAf[], Makie.RGBAf[], Float32[]
        )
    )

    # Positions are block-relative; the text recipe shifts each spec by the
    # projected block position and patches `space`/`markerspace` to match.
    push!(
        outputs.text_specs, Makie.PlotSpec(
            :Scatter, [Makie.Point3f(0, 0, 0)];
            marker = [cached],
            markersize = [dim_pt],
            marker_offset = [marker_offset],
            rotation = [rot],
        )
    )
    push!(outputs.text_spec_block_indices, i)

    # Report `ink_size` as the bbox so block-level layout (axis title gaps,
    # tick label padding, etc.) doesn't include the `crop_margin_pt` pad —
    # that pad exists only to keep the rasterized marker's anti-aliased
    # edges intact, not as visual space around the text.
    half = 0.5f0 .* Makie.Vec3f(ink_size..., 0)
    bb = Makie.Rect3d(Makie.to_ndim(Makie.Point3d, marker_offset, 0) .- half, Makie.Vec3d(ink_size..., 0))
    push!(outputs.text_spec_bboxes, Makie.rotate_bbox(bb, rot))
    return
end

# Sub-pt-precise crop via Ghostscript's `%%HiResBoundingBox`. The integer
# `%%BoundingBox` jitters glyph edges by up to ~1pt, visible as baseline drift.
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

# Run latexmk/tectonic in a tempdir and parse `temp.log` for the box depth
# before tearing the dir down.
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

# GPU backends (GL/WGLMakie) call this to turn a cached document into a
# texture-uploadable image. CairoMakie has its own vector dispatch and
# doesn't reach this path.
_makietex_density_for_size(s) = max(2, ceil(Int, maximum(s) / 8))

function Makie.rasterize_marker_for_gpu(doc::AbstractCachedDocument, scale)
    s = scale isa AbstractVector ? first(scale) : scale
    return page2img(doc, doc.doc isa Nothing ? 0 : doc.doc.page;
        render_density = _makietex_density_for_size(s))
end

function Makie.rasterize_marker_for_gpu(docs::AbstractVector{<:AbstractCachedDocument}, scale)
    sizes = scale isa AbstractVector ? scale : fill(scale, length(docs))
    return [
        page2img(d, d.doc isa Nothing ? 0 : d.doc.page;
            render_density = _makietex_density_for_size(sz))
            for (d, sz) in zip(docs, sizes)
    ]
end
