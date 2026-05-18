# Engine-agnostic core for PDF-marker text handlers. Concrete handlers
# (defined in extensions) subtype `AbstractPdfTextHandler` and override
# `Makie.compile_text` to return `(CachedPDF, baseline_pt)`. The shared
# `place_text!` here turns that payload into a Makie scatter spec plus a
# bbox aligned to the requested anchor.

"""
    AbstractPdfTextHandler

Shared supertype for text handlers whose `compile_text` produces a
`(CachedPDF, baseline_pt)` tuple. `place_text!` is implemented once on this
supertype; concrete handlers only need to override `compile_text`.

Concrete handlers live in extensions: `AbstractLaTeX` (via
`MakieTeXLaTeXExt`) and `AbstractTypst` (via `MakieTeXTypstExt`).
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
