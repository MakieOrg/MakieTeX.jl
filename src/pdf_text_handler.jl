# Engine-agnostic core for PDF-marker text handlers. Concrete handlers
# (defined in extensions) subtype `AbstractPdfTextHandler` and add
# `compile_pdf_text` methods returning a `CompiledPdfText`. The single
# `Makie.emit_text!` method here turns that into a Makie scatter spec plus the
# layout frame Makie aligns and rotates it in, shared across engines.

"""
    AbstractPdfTextHandler

Shared supertype for text handlers whose `compile_pdf_text` produces a
[`CompiledPdfText`](@ref). The `Makie.emit_text!` method is shared, so concrete
handlers only add `compile_pdf_text` methods for the input types they accept.

Concrete handlers live in extensions: [`LaTeX`](@ref) (via
`MakieTeXLaTeXExt`) and [`Typst`](@ref) (via `MakieTeXTypstExt`).
"""
abstract type AbstractPdfTextHandler end

"""
    CompiledPdfText(doc, baseline_pt, crop_margin_pt)

Payload returned by a PDF-marker handler's `compile_pdf_text`: the rendered
document, the baseline depth (markerspace pt below the ink bottom, for
`valign = :baseline`), and the crop margin padded around the ink.
"""
struct CompiledPdfText{D <: AbstractDocument}
    doc::D
    baseline_pt::Float32
    crop_margin_pt::Float32
end

"""
    compile_pdf_text(handler, src, fontsize, lineheight, color) -> Union{CompiledPdfText, Nothing}

Engine step of a PDF-marker handler. Extensions add methods dispatching on the
handler and the input type it accepts, and return `nothing` to fall through to
Makie's own text layout.
"""
compile_pdf_text(handler, src, fontsize, lineheight, color) = nothing

function Makie.emit_text!(
        buffer, h::AbstractPdfTextHandler, src, font, fonts, fontsize,
        lineheight, justification, word_wrap_width, color, strokecolor, strokewidth
    )
    compiled = compile_pdf_text(h, src, fontsize, lineheight, color)
    compiled === nothing && return false
    push_pdf_text!(buffer, compiled)
    return true
end

function push_pdf_text!(buffer, c::CompiledPdfText)
    doc = c.doc

    # The PDF is already at the correct fontsize; markersize is the literal
    # PDF dimensions. `crop_margin_pt` was padded around the ink at crop time,
    # so the natural ink box is `dim_pt - 2 * crop_margin_pt`.
    dim_pt = Makie.Vec2f(Float32(doc.dims[1]), Float32(doc.dims[2]))
    ink_size = dim_pt .- 2 * c.crop_margin_pt

    # Layout frame: the ink sits with its left/bottom corner on the origin and
    # its baseline `baseline_pt` above the bottom. Reporting `ink_size` rather
    # than `dim_pt` keeps `crop_margin_pt` out of block-level layout (axis title
    # gaps, tick label padding); that pad exists only to keep the rasterized
    # marker's anti-aliased edges intact, not as visual space around the text.
    bbox = Makie.Rect2f(0, 0, ink_size[1], ink_size[2])
    Makie.push_empty_block!(buffer; bbox = bbox, baseline = c.baseline_pt)

    # A scatter marker is drawn centered on its position, so the layout position
    # is the middle of the ink box. `markersize` is the long dimension; aspect is
    # handled per-backend (rescale_marker on GL, draw_marker on Cairo), so this
    # expands back out to a Vec2(w, h) box. The identity `rotation` is what
    # placement composes the text rotation into, turning the ink with the text.
    spec = Makie.PlotSpec(
        :Scatter, [Makie.Point3f(0.5f0 * ink_size[1], 0.5f0 * ink_size[2], 0)];
        marker = [doc],
        markersize = [Float32(maximum(dim_pt))],
        rotation = [Makie.Quaternionf(0, 0, 0, 1)],
    )
    Makie.push_text_spec!(buffer, spec, Makie.Rect3d(Makie.Point3d(0), Makie.Vec3d(ink_size..., 0)))
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

# GPU backends (GL/WGLMakie) call this to turn a document into a
# texture-uploadable image. CairoMakie has its own vector dispatch and
# doesn't reach this path.
#
# Ideal behavior would re-rasterize at the current screen's `px_per_unit`
# on every render so the texture pixel grid matches the framebuffer
# exactly (no over/undersampling). That needs Makie-side plumbing — the
# compute graph for marker upload currently doesn't see `px_per_unit`,
# which lives on the screen and only fires per render. Until that hook
# exists, this Ref is a manual stand-in: set it to the `px_per_unit` of
# your typical save target. Default 2× matches `save(...; px_per_unit = 2)`
# (the recommended default for raster export) without resampling, and
# only slightly oversamples 1× interactive display.
const TEXTURE_RENDER_DENSITY = Ref(2)

Makie.rasterize_marker_for_gpu(doc::AbstractDocument, scale) =
    rasterize(doc; render_density = TEXTURE_RENDER_DENSITY[])

Makie.rasterize_marker_for_gpu(docs::AbstractVector{<:AbstractDocument}, scale) =
    [rasterize(d; render_density = TEXTURE_RENDER_DENSITY[]) for d in docs]
