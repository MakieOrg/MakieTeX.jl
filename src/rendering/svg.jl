#=
# SVG rendering

This file contains the code for rendering SVG files using the Rsvg library.

It uses the Rsvg.jl package to parse the SVG file and render it to a Cairo context.

Finally, it implements the MakieTeX cached-document API.
=#

function CachedSVG(svg::SVGDocument)
    handle = svg2rsvg(svg.doc)
    surf, ctx = rsvg2recordsurf(handle)
    dh = Rsvg.handle_get_dimensions(handle)
    dims = Float64.((dh.width, dh.height))
    return CachedSVG(svg, handle, dims, surf)
end

function rasterize(ct::CachedSVG, scale::Real = 1)
    if last(ct.image_cache[]) == scale
        return first(ct.image_cache[])
    else
        img = rsvg2img(ct.handle[], scale)
        ct.image_cache[] = (img, scale)
        return img
    end
end

# First, fill in missing parts of the `Rsvg.jl` API which allow us to use new and approve Rsvg primitives.

"""
RsvgRectangle is a simple struct of:
    height::Float64
    width::Float64
    x::Float64
    y::Float64
"""
struct _RsvgRectangle
    height::Float64
    width::Float64
    x::Float64 # origin
    y::Float64 # origin
end

"""
handle_render_document(cr::CairoContext, handle::RsvgHandle, viewport::_RsvgRectangle)
"""
function handle_render_document(cr::CairoContext, handle::RsvgHandle, viewport::_RsvgRectangle)
	ccall((:rsvg_handle_render_document, Rsvg.Librsvg_jll.librsvg), Bool,
        (Rsvg.RsvgHandle, Ptr{Nothing}, Ref{_RsvgRectangle}, Ptr{Nothing}), handle, cr.ptr, Ref(viewport), C_NULL)
end

function svg2rsvg(svg::String, dpi = 72.0)
    handle = Rsvg.handle_new_from_data(svg)
    Rsvg.handle_set_dpi(handle, Float64(dpi))
    return handle
end

function rsvg2recordsurf(handle::Rsvg.RsvgHandle)
    surf = Cairo.CairoRecordingSurface()
    ctx  = Cairo.CairoContext(surf)
    d = Rsvg.handle_get_dimensions(handle)
    handle_render_document(ctx, handle, _RsvgRectangle(d.height, d.width, 0, 0))
    return (surf, ctx)
end

function rsvg2img(handle::Rsvg.RsvgHandle, scale::Float64; dpi = 72.0)
    @assert scale > 0.0 "Scale must be positive"
    Rsvg.handle_set_dpi(handle, Float64(dpi))

    # We can find the final dimensions (in pixel units) of the Rsvg image.
    # Then, it's possible to store the image in a native Julia array,
    # which simplifies the process of rendering.
    d = Rsvg.handle_get_dimensions(handle)

    # Cairo does not draw "empty" pixels, so we need to fill here
    w, h = round(Int, d.width * scale), round(Int, d.height * scale)

    img = fill(Colors.ARGB32(1,1,1,0), w, h)

    # Cairo allows you to use a Matrix of ARGB32, which simplifies rendering.
    surface = Cairo.CairoImageSurface(img)
    ctx = Cairo.CairoContext(cs)
    Cairo.scale(ctx, w/d.width, h/d.height)
    # Render the parsed SVG to a Cairo context
    Rsvg.handle_render_cairo(c, handle)

    # The image is rendered transposed, so we need to flip it.
    return rotr90(permutedims(img))
end

