module MakieTeXCairoMakieExt

using CairoMakie, MakieTeX
using Makie
using Poppler_jll
using Cairo

function CairoMakie.cairo_scatter_marker(marker::MakieTeX.AbstractDocument)
    return Cached(marker)
end

function CairoMakie.cairo_scatter_marker(marker::MakieTeX.AbstractCachedDocument)
    return marker
end

CairoMakie.cairo_scatter_marker(v::AbstractArray{<:MakieTeX.AbstractDocument}) = CairoMakie.cairo_scatter_marker.(v)
CairoMakie.cairo_scatter_marker(v::NTuple{N, <:MakieTeX.AbstractDocument}) where {N} = CairoMakie.cairo_scatter_marker.(v)

# Vector-render a cached PDF marker via Poppler — no raster intermediate.
function CairoMakie.draw_marker(
        ctx, marker::Union{MakieTeX.CachedPDF, MakieTeX.CachedTypst}, pos,
        strokecolor, strokewidth, mat
    )
    w, h = marker.dims
    document = MakieTeX.update_handle!(marker)
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid}, (Ptr{Cvoid}, Cint), document, marker.doc.page
    )
    Cairo.translate(ctx, pos[1], pos[2])
    CairoMakie.cairo_transform(ctx, mat)
    Cairo.scale(ctx, 1.0 / w, 1.0 / h)
    Cairo.translate(ctx, -w / 2, -h / 2)
    ccall(
        (:poppler_page_render, Poppler_jll.libpoppler_glib),
        Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), page, ctx.ptr
    )
    return
end

end
