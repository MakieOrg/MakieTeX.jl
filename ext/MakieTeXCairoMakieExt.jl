module MakieTeXCairoMakieExt

using CairoMakie, MakieTeX
using Makie
using Makie.MakieCore
using Poppler_jll
using Cairo
using Colors
using Rsvg
using Base64

# # Teximg

# Override `is_cairomakie_atomic_plot` to allow `TeXImg` to remain a unit,
# instead of auto-decomposing into its component scatter plot.
CairoMakie.is_cairomakie_atomic_plot(plot::TeXImg) = true


# CairoMakie direct drawing method
function draw_tex(scene, screen::CairoMakie.Screen, cachedtex::MakieTeX.CachedTeX, position::VecTypes, scale::VecTypes, rotation::Real, align::Tuple{Symbol, Symbol})
    # establish some initial values
    w, h = cachedtex.dims
    ctx = screen.context
    # First we center the position with respect to the center of the image,
    # regardless of its alignment.  This ensures that rotation takes place
    # in the correct "axis" (2d).
    position = position .+ (-scale[1]/2, scale[2]/2)


    # Then, we find the appropriate "marker offset" w.r.t. alignment.
    # This is separate because of Cairo's reversed y-axis.
    halign, valign = align
    offset_pos = Point2f(0)
    # First, we handle the horizontal alignment
    offset_pos = if halign == :left
        offset_pos .- (-scale[1] / 2, 0)
    elseif halign == :center
        offset_pos .- (0, 0)
    elseif halign == :right
        offset_pos .- (scale[1] / 2, 0)
    end
    # and then the vertical alignment.
    offset_pos = if valign == :top
        offset_pos .+ (0, scale[2]/2)
    elseif valign == :center
        offset_pos .+ (0, 0)
    elseif valign == :bottom
        offset_pos .- (0, scale[2]/2)
    end

    # Calculate, with respect to the rotation, where the rotated center of the image
    # should be.
    # (Rotated center - Normal center)
    cx = 0.5scale[1] * cos(rotation) - 0.5scale[2] * sin(rotation) - 0.5scale[1]
    cy = 0.5scale[1] * sin(rotation) + 0.5scale[2] * cos(rotation) - 0.5scale[2]

    # Begin the drawing and translation process
    Cairo.save(ctx)
    # translate to normal position
    Cairo.translate(
        ctx,
        position[1],
        position[2] - scale[2]
    )
    # rotate context by required rotation
    Cairo.rotate(ctx, -rotation)
    # cairo rotates around position as an axis,
    #compensate for that with previously calculated values
    Cairo.translate(ctx, cx, cy)
    # apply "marker offset" to implement/simulate alignment
    Cairo.translate(ctx, offset_pos[1], offset_pos[2])
    # scale the marker appropriately
    Cairo.scale(
        ctx,
        scale[1] / w,
        scale[2] / h
    )
    # the rendering pipeline
    # first is the "safe" Poppler pipeline, with better results in PDF
    # and PNG, especially when rotated.
    if !(MakieTeX.RENDER_EXTRASAFE[])
        # retrieve a new Poppler document pointer
        document = MakieTeX.update_pointer!(cachedtex)
        # retrieve the first page
        page = ccall(
            (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
            Ptr{Cvoid},
            (Ptr{Cvoid}, Cint),
            document, 0 # page 0 is first page
        )
        # Render the page to the surface
        ccall(
            (:poppler_page_render, Poppler_jll.libpoppler_glib),
            Cvoid,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            page, ctx.ptr
        )
    else # "extra-safe" Cairo pipeline, also somewhat faster.
        # render the cached CairoSurface to the screen.
        # bad with PNG output though.
        Cairo.set_source(ctx, cachedtex.surf, 0, 0)
        Cairo.paint(ctx)
    end
    # restore context and end
    Cairo.restore(ctx)
end

function CairoMakie.draw_plot(scene::Makie.Scene, screen::CairoMakie.Screen, img::T) where T <: MakieTeX.TeXImg

    broadcast_foreach(img[1][], img.position[], img.scale[], CairoMakie.remove_billboard(img.rotation[]), img.align[]) do cachedtex, position, scale, rotation, align

        w, h = cachedtex.dims

        pos = CairoMakie.project_position(
            scene, img.space[],
            Makie.apply_transform(scene.transformation.transform_func[], position),
            img.model[]
        )

        _w = scale * w; _h = scale * h
        scale_factor = CairoMakie.project_scale(scene, img.space[], Vec2{Float32}(_w, _h), img.model[])

        draw_tex(scene, screen, cachedtex, pos, scale_factor, rotation, align)

    end

end

# # Scatter markers

function cairo_pattern_get_rgba(pattern::CairoPattern)
    r, g, b, a = (Ref(0.0) for _ in 1:4)
    @ccall Cairo.Cairo_jll.libcairo.cairo_pattern_get_rgba(pattern.ptr::Ptr{Cvoid}, r::Ptr{Cdouble}, g::Ptr{Cdouble}, b::Ptr{Cdouble}, a::Ptr{Cdouble})::Cint
    return RGBA{Float64}(r[], g[], b[], a[])
end

function rsvg_handle_set_stylesheet(handle::RsvgHandle, style_string::String)
    gerror_hhandle = Ref(C_NULL)
    ret = @ccall Rsvg.Librsvg_jll.librsvg.rsvg_handle_set_stylesheet(handle.ptr::Ptr{Cvoid}, style_string::Cstring, length(style_string)::Csize_t, gerror_hhandle::Ptr{Cvoid})::Bool
    if gerror_hhandle[] != C_NULL
        @warn("MakieTeX: Failed to set stylesheet for Rsvg handle.")
        # there was some error, so handle it
    end
    return ret
end

function CairoMakie.draw_marker(ctx, marker::MakieTeX.CachedSVG, pos, scale,
    strokecolor #= unused =#, strokewidth #= unused =#,
    marker_offset, rotation) 
    Cairo.save(ctx)
    # Obtain the initial color from the pattern.  
    # This allows us to support marker coloring by CSS themes.
    pattern = Cairo.get_source(ctx)
    color = cairo_pattern_get_rgba(pattern)
    # Generate a CSS style string for the SVG.
    style_string = """
        svg { 
            fill: #$(Colors.hex(Colors.color(color))); 
            fill-opacity: $(Colors.alpha(color)); 
            stroke: #$(Colors.hex(Colors.color(strokecolor))); 
            stroke-opacity: $(Colors.alpha(strokecolor)); 
            stroke-width: $strokewidth; 
    }"""
    # Set the stylesheet for the Rsvg handle
    # Here, we generate the Rsvg handle from the original SVG document, and don't use the cached version.
    # This is because I'm not sure whether the repeated setting of the stylesheeet will affect the cached version.
    # If it does not, then we can simply replace this line with `marker.handle[]`,
    # and go about our merry way.
    svg_string = marker.doc.doc
    handle = MakieTeX.svg2rsvg(svg_string)
    rsvg_handle_success = rsvg_handle_set_stylesheet(handle, style_string)
    rsvg_handle_success || @warn("MakieTeX: Failed to set stylesheet for Rsvg handle.")
    # Begin the drawing process
    Cairo.translate(ctx,
                    pos[1] #= the initial marker position =# + marker_offset[1] #= the marker offset =# - scale[1]#= center of the marker =#,
                    pos[2] #= the initial marker position =# + marker_offset[2] #= the marker offset =# - scale[2]#= center of the marker =#,)
    Cairo.rotate(ctx, CairoMakie.to_2d_rotation(rotation))
    MakieTeX.handle_render_document(ctx, handle, MakieTeX._RsvgRectangle(scale[2], scale[1], scale[1], scale[2]))
    Cairo.restore(ctx)
end



end