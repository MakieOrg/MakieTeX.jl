# SVG rendering via librsvg + Cairo.

# `rsvg_handle_render_document` takes a viewport rectangle in user units.
struct _RsvgRectangle
    x::Cdouble
    y::Cdouble
    width::Cdouble
    height::Cdouble
end

"""
    load_svg(bytes::Vector{UInt8}) -> Ptr{Cvoid}

Parse SVG bytes into a librsvg handle. Throws on malformed input.
"""
function load_svg(bytes::Vector{UInt8})::Ptr{Cvoid}
    err_ref = Ref{Ptr{Cvoid}}(C_NULL)
    handle = ccall(
        (:rsvg_handle_new_from_data, Librsvg_jll.librsvg),
        Ptr{Cvoid}, (Ptr{UInt8}, Csize_t, Ref{Ptr{Cvoid}}),
        bytes, length(bytes), err_ref,
    )
    handle == C_NULL && error("librsvg could not parse the SVG data.")
    return handle
end

"""
    svg_get_size(handle::Ptr{Cvoid}) -> Tuple{Float64, Float64}

Return the SVG's intrinsic size in pixels (1 px == 1 pt at 72 dpi).
"""
function svg_get_size(handle::Ptr{Cvoid})::Tuple{Float64, Float64}
    width = Ref{Cdouble}(0.0)
    height = Ref{Cdouble}(0.0)
    ccall(
        (:rsvg_handle_get_intrinsic_size_in_pixels, Librsvg_jll.librsvg),
        Cint, (Ptr{Cvoid}, Ref{Cdouble}, Ref{Cdouble}),
        handle, width, height,
    )
    return (Float64(width[]), Float64(height[]))
end

"""
    render_svg_to_cairo(ctx::Cairo.CairoContext, svg::SVG)

Render `svg` into `ctx` at its intrinsic size (origin at (0, 0)).
"""
function render_svg_to_cairo(ctx::Cairo.CairoContext, svg::SVG)
    w, h = svg.dims
    viewport = _RsvgRectangle(0.0, 0.0, w, h)
    err_ref = Ref{Ptr{Cvoid}}(C_NULL)
    ok = ccall(
        (:rsvg_handle_render_document, Librsvg_jll.librsvg),
        Bool, (Ptr{Cvoid}, Ptr{Nothing}, Ref{_RsvgRectangle}, Ref{Ptr{Cvoid}}),
        svg.handle.ptr, ctx.ptr, Ref(viewport), err_ref,
    )
    ok || error("librsvg failed to render SVG document.")
    return
end

"""
    rasterize(svg::SVG; render_density = 1) -> Matrix{ARGB32}

Rasterize the SVG to an ARGB32 image at `render_density` pixels per pt.
"""
function rasterize(svg::SVG; render_density::Real = 1)
    w_pt, h_pt = svg.dims
    w = ceil(Int, w_pt * render_density)
    h = ceil(Int, h_pt * render_density)

    img = fill(Colors.ARGB32(0, 0, 0, 0), w, h)
    surf = CairoImageSurface(img)
    ccall(
        (:cairo_surface_set_device_scale, Cairo.libcairo), Cvoid,
        (Ptr{Nothing}, Cdouble, Cdouble),
        surf.ptr, render_density, render_density,
    )
    ctx = Cairo.CairoContext(surf)
    Cairo.set_antialias(ctx, Cairo.ANTIALIAS_BEST)
    render_svg_to_cairo(ctx, svg)
    Cairo.finish(surf)
    return permutedims(img)
end
