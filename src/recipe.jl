# Support attribute values of:
# scale::Real
# render_density::Real
# rotations::Vector{Real}
"""
    teximg(tex; position, ...)
    teximg!(ax_or_scene, tex; position, ...)

This recipe plots rendered `TeX` to your Figure or Scene.  

There are three types of input you can provide:
- Any `String`, which is rendered to LaTeX cognizant of the figure's overall theme,
- A [`TeXDocument`](@ref) object, which is rendered to LaTeX directly, and can be customized by the user,
- A [`CachedTeX`](@ref) object, which is a pre-rendered LaTeX document.

`tex` may be a single one of these objects, or an array of them.

## Attributes
$(Makie.ATTRIBUTES)
"""
@recipe(TeXImg, tex) do scene
    merge(
        default_theme(scene),
        Attributes(
            render_density = 2,
            align = (:center, :center),
            scale = 1.0,
            position = [Point2{Float32}(0)],
            rotation = [0f0],
            space = :data,
            markerspace = :pixel
        )
    )
end

# First, handle the case of one or more abstract strings passed in!
# These are themable.

# Makie.used_attributes(::Type{<: TeXImg}, string_s::Union{<: AbstractString, AbstractVector{<: AbstractString}}) = (:font, :fontsize, :justification, :color, :word_wrap_width, :lineheight)
# Makie.convert_arguments(::Type{<: TeXImg}, string::AbstractString) = Makie.convert_arguments(TeXImg, [string])

# function Makie.convert_arguments(
#     ::Type{<: TeXImg},
#     strings::AbstractVector{<: AbstractString};
#     font = Makie.texfont(), 
#     fontsize = 14, 
#     justification = Makie.automatic, 
#     color = :black, 
#     word_wrap_width = -1,
#     lineheight = 1.0,
#     )

#     # This function will convert the strings to CachedTeX, so that it can track changes in attributes.
#     # It will have to handle the case where the parameters given are for all strings in an array, or per string,
#     # using Makie's `broadcast_foreach` function.

#     # First, we need to convert the strings to CachedTeX.
#     # This is done by using the `CachedTeX` constructor, which will render the LaTeX and store it in a CachedTeX object.
#     # This is then stored in an array, which is then returned.


# EPSDocument
function offset_from_align(align::Tuple{Symbol, Symbol}, wh)::Vec2f

    (halign::Symbol, valign::Symbol) = align
    w, h = wh[1], wh[2]

    x = -w / 2
    y = -h / 2

    if halign == :left
        x += w/2
    elseif halign == :center
        x -= 0
    elseif halign == :right
        x -= w/2
    end

    if valign == :top
        y -= h/2
    elseif valign == :center
        y -= 0
    elseif valign == :bottom
        y -= -h/2
    end

    return Vec2f(x, y)
end

_bc_if_array(f, x) = f(x)
_bc_if_array(f, x::AbstractArray) = f.(x)

# scatter: marker size, rotations to determine everything
function Makie.plot!(plot::TeXImg)
    # We always want to draw this at a 1:1 ratio, so increasing scale or
    # changing dpi should rerender
    plottable_images = lift(plot[1], plot.render_density, plot.scale) do cachedtex, render_density, scale
        if cachedtex isa AbstractString || cachedtex isa AbstractArray{<: AbstractString}
            to_array(_bc_if_array(CachedTEX, cachedtex))
        else
            to_array(_bc_if_array(Cached, cachedtex))
        end
    end

    scatter_images    = Observable(plottable_images[])
    scatter_positions = Observable{Vector{Point2f}}()
    scatter_sizes     = Observable{Vector{Vec2f}}()
    scatter_offsets   = Observable{Vector{Vec2f}}()
    scatter_rotations = Observable{Any}()

    # Rect to draw in
    # This is mostly aligning
    onany(plot, plottable_images, plot.position, plot.rotation, plot.align, plot.scale) do images, pos, rotations, align, scale
        if length(images) != length(pos) && !(pos isa Makie.VecTypes)
            # skip this update and let the next one propagate
            @debug "TeXImg: Length of images ($(length(images))) != length of positions ($(length(pos))).  Skipping this update."
            return
        end

        scatter_images.val    = images
        scatter_positions.val = pos isa Makie.VecTypes{N, <: Number} where N ? [pos] : collect(pos)
        scatter_sizes.val     = (Vec2f.(size.(images))) .* scale
        scatter_offsets.val   = offset_from_align.((align,), scatter_sizes.val)
        scatter_rotations.val = rotations

        notify(scatter_images)
        notify(scatter_positions)
        notify(scatter_sizes)
        notify(scatter_offsets)
        notify(scatter_rotations)
    end

    notify(plot.position) # trigger the first update

    scatter!(
        plot,
        scatter_positions;
        marker = scatter_images,
        markersize = scatter_sizes,
        marker_offset = scatter_offsets,
        rotation = scatter_rotations,
        space = plot.space,
        markerspace = plot.markerspace,
    )
end

# CairoMakie direct drawing method
function draw_tex(scene::Scene, screen::CairoMakie.Screen, cachedtex::CachedTeX, position::VecTypes, scale::VecTypes, rotation::Real, align::Tuple{Symbol, Symbol})
    # establish some initial values
    x0, y0 = 0.0, 0.0
    w, h = cachedtex.dims
    ctx = screen.context
    # First we center the position with respect to the center of the image,
    # regardless of its alignment.  This ensures that rotation takes place
    # in the correct "axis" (2d).
    position = position .+ (-scale[1]/2, scale[2]/2)


    # Then, we find the appropriate "marker offset" w.r.t. alignment.
    # This is separate because of Cairo's reversed y-axis.
    halign, valign = align
    pos = Point2f(0)
    pos = if halign == :left
        pos .- (-scale[1] / 2, 0)
    elseif halign == :center
        pos .- (0, 0)
    elseif halign == :right
        pos .- (scale[1] / 2, 0)
    end

    pos = if valign == :top
        pos .+ (0, scale[2]/2)
    elseif valign == :center
        pos .+ (0, 0)
    elseif valign == :bottom
        pos .- (0, scale[2]/2)
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
    Cairo.translate(ctx, pos[1], pos[2])
    # scale the marker appropriately
    Cairo.scale(
        ctx,
        scale[1] / w,
        scale[2] / h
    )
    # the rendering pipeline
    # first is the "safe" Poppler pipeline, with better results in PDF
    # and PNG, especially when rotated.
    if !(RENDER_EXTRASAFE[])
        # retrieve a new Poppler document pointer
        document = update_pointer!(cachedtex)
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

function CairoMakie.draw_plot(scene::Scene, screen::CairoMakie.Screen, img::T) where T <: MakieTeX.TeXImg

    broadcast_foreach(img[1][], img.position[], img.scale[], CairoMakie.remove_billboard(img.rotations[]), img.align[]) do cachedtex, position, scale, rotation, align

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

"""
    tex_annotation!(axis::Axis, lstring, x, y; mainfont = nothing, mathfont = nothing, scale_factor=1)

Add TeX annotation to an existing Makie Axis. Under the hood, it does a few things:

1. via `mathspec` LaTeX package, we set the `mainfont` and `mathfont`
2. Render it using `tectonic_jll` and convert to an image matrix.
3. call `Makie.scatter!` and using the image as `marker`, scale the image by `scale_factor` while preserving aspec ratio.

    !!! note
You can use `\textcolor` from `xcolor` inside the latex string.
"""
function tex_annotation!(axis::Axis, lstring, x, y; mainfont = nothing, mathfont = nothing, scale_factor=1)
    texdoc = TeXDocument(
        String(lstring), true;
        requires = "\\RequirePackage{luatex85}",
        preamble = """
        \\usepackage{amsmath, xcolor}
        \\usepackage{mathspec}
        \\pagestyle{empty}
        $(isnothing(mainfont) ? "" :
        "\\setmainfont{$mainfont}[Scale=MatchLowercase, Ligatures=TeX]"
       )
        $(isnothing(mathfont) ? "" :
        "\\setmathfont(Digits,Latin)[Scale=MatchLowercase]{$mathfont}"
       )
        """,
        class = "standalone",
        classoptions = "preview, tightpage, 12pt"
    )
    tex = CachedTeX(texdoc)
    marker = MakieTeX.rotl90(MakieTeX.recordsurf2img(tex, 4))
    scatter!(axis, x, y; marker, markersize=tex.dims .* scale_factor)
end
