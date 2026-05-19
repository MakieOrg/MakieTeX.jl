module MakieTeXCairoMakieExt

using CairoMakie, MakieTeX
using MakieTeX: PDF, SVG, AbstractDocument, ensure_loaded!, render_svg_to_cairo
using Makie
using Poppler_jll
using Cairo

CairoMakie.cairo_scatter_marker(marker::AbstractDocument) = marker
CairoMakie.cairo_scatter_marker(v::AbstractArray{<:AbstractDocument}) = v
CairoMakie.cairo_scatter_marker(v::NTuple{N, <:AbstractDocument}) where {N} = v

function CairoMakie.draw_marker(
        ctx, marker::PDF, pos,
        strokecolor, strokewidth, mat,
    )
    ensure_loaded!(marker)
    w, h = marker.dims[]
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid}, (Ptr{Cvoid}, Cint), marker.handle[], marker.page,
    )
    Cairo.translate(ctx, pos[1], pos[2])
    CairoMakie.cairo_transform(ctx, mat)
    Cairo.scale(ctx, 1.0 / w, 1.0 / h)
    Cairo.translate(ctx, -w / 2, -h / 2)
    ccall(
        (:poppler_page_render, Poppler_jll.libpoppler_glib),
        Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), page, ctx.ptr,
    )
    return
end

function CairoMakie.draw_marker(
        ctx, marker::SVG, pos,
        strokecolor, strokewidth, mat,
    )
    ensure_loaded!(marker)
    w, h = marker.dims[]
    Cairo.translate(ctx, pos[1], pos[2])
    CairoMakie.cairo_transform(ctx, mat)
    Cairo.scale(ctx, 1.0 / w, 1.0 / h)
    Cairo.translate(ctx, -w / 2, -h / 2)
    render_svg_to_cairo(ctx, marker)
    return
end

end
