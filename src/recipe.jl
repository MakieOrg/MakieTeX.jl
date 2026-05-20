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
"""
@recipe TeXImg (tex,) begin
    "Density at which the rendered document is rasterised (1 means 1 px == 1 pt)."
    render_density = 2
    "Alignment of the rendered document relative to its `position`, as a `(halign, valign)` tuple of `:left`/`:center`/`:right` and `:top`/`:center`/`:bottom`."
    align = (:center, :center)
    "Uniform scaling factor applied to the rendered document."
    scale = 1.0
    "Position(s) at which to draw the document(s)."
    position = [Point2{Float32}(0)]
    "Counter-clockwise rotation in radians."
    rotation = [0f0]
    "Space in which `markersize` is interpreted. See `Makie.spaces()`."
    markerspace = :pixel
    Makie.mixin_generic_plot_attributes()...
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

_normalise_positions(pos::Makie.VecTypes{N, <:Number}) where {N} = [pos]
_normalise_positions(pos) = collect(pos)

# Convert the recipe's `tex` argument into a `Vector{<:AbstractCachedDocument}`,
# regardless of whether the user supplied a String, a (Cached)Document, or
# an array of either.
function _plottable_images(tex)
    if tex isa AbstractString || tex isa AbstractArray{<:AbstractString}
        return to_array(_bc_if_array(CachedTEX, tex))
    else
        return to_array(_bc_if_array(Cached, tex))
    end
end

function Makie.plot!(plot::TeXImg)
    # Derive everything via `map!` so it lives inside the plot's compute graph.
    # This is what makes updates flow through to the inner scatter on Makie 0.24
    # -- a stray Observable + onany bridge does not, because the graph is lazy
    # and only fires when downstream Computed nodes are invalidated.

    map!(plot, [:tex], :_plottable_images) do tex
        _plottable_images(tex)
    end

    map!(plot, [:_plottable_images, :position], :_scatter_positions) do images, pos
        positions = _normalise_positions(pos)
        if length(images) != length(positions)
            # Length mismatch: broadcast a single position so we render something
            # plausible without crashing.
            return fill(first(positions), length(images))
        end
        return positions
    end

    map!(plot, [:_plottable_images, :scale], :_scatter_sizes) do images, scale
        return (Vec2f.(size.(images))) .* scale
    end

    map!(plot, [:_scatter_sizes, :align], :_scatter_offsets) do sizes, align
        return offset_from_align.((align,), sizes)
    end

    scatter!(
        plot,
        plot._scatter_positions;
        marker = plot._plottable_images,
        markersize = plot._scatter_sizes,
        marker_offset = plot._scatter_offsets,
        rotation = plot.rotation,
        space = plot.space,
        markerspace = plot.markerspace,
    )
end
