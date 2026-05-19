module MakieTeXCairoMakieExt

using CairoMakie, MakieTeX
using MakieTeX: PDF, SVG, AbstractDocument, render_svg_to_cairo
using Makie
using Poppler_jll
using Cairo

CairoMakie.cairo_scatter_marker(marker::AbstractDocument) = marker
CairoMakie.cairo_scatter_marker(v::AbstractArray{<:AbstractDocument}) = v
CairoMakie.cairo_scatter_marker(v::NTuple{N, <:AbstractDocument}) where {N} = v

# `Cairo.scale(ctx, 1/m, 1/m)` instead of `1/w, 1/h` makes the marker
# fill the longer dimension of the markersize box and scale the shorter
# dimension proportionally — same aspect-preserving convention as
# `rescale_marker` on GL backends and as Char glyphs render naturally.
function CairoMakie.draw_marker(
        ctx, marker::PDF, pos,
        strokecolor, strokewidth, mat,
    )
    w, h = marker.dims
    m = max(w, h)
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid}, (Ptr{Cvoid}, Cint), marker.handle.ptr, marker.page,
    )
    Cairo.translate(ctx, pos[1], pos[2])
    CairoMakie.cairo_transform(ctx, mat)
    Cairo.scale(ctx, 1.0 / m, 1.0 / m)
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
    w, h = marker.dims
    m = max(w, h)
    Cairo.translate(ctx, pos[1], pos[2])
    CairoMakie.cairo_transform(ctx, mat)
    Cairo.scale(ctx, 1.0 / m, 1.0 / m)
    Cairo.translate(ctx, -w / 2, -h / 2)
    render_svg_to_cairo(ctx, marker)
    return
end

end
