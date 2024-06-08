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
