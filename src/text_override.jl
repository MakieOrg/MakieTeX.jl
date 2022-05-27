# Here, we override the plotting function for Text
# to plot a TeXImg for either a TeXDocument or a CachedTeX
# passed in.

function fontsize(fontsize::Real, lineheight)
    return """
    \\fontsize{$(fontsize)}{$(fontsize * lineheight)}
    """
end

function define_mathfontsize(fontsize::Real, math_inc::Real, sub_mult::Real, subsub_mult::Real)
    return "\\DeclareMathSizes{$(fontsize)}{$(fontsize + math_inc)}{$(fontsize * sub_mult)}{$(fontsize * subsub_mult)}"
end

function define_mathfontsizes(fontsizes::AbstractVector{<: Real}; math_incs = fill(.5, length(fontsizes)), sub_mults = fill(7/12, length(fontsizes)), subsub_mults = fill(7/12/1.5, length(fontsizes)))
    return join(define_mathfontsize.(fontsizes, math_incs, sub_mults, subsub_mults), "\n", "\n\n")
end

# The main theme-enabled function, which takes in information from multiple places
# and spreads them out!
function to_plottable_cachedtex(lstr, font, textsize, lineheight, color)
    # $(usemain && raw"\usepackage{fontspec}")
    packages = [
        # math stuff
        "amsmath", "amssymb", "amsfonts", "esint",
        # color management
        "xcolor",
    ]
    # smart detect tikz to decrease load time
    if occursin("tikz", lstr)
        push!(packages, "tikz")
    end

    package_load_str = raw"\usepackage{" * join(packages, ", ") * raw"}"


    preamble = """

    \\usepackage{lmodern}
    \\usepackage[T1]{fontenc}
    $(package_load_str)
    \\definecolor{maincolor}{HTML}{$(Makie.Colors.hex(RGBf(color)))}
    $(define_mathfontsize(textsize, .5, 7/12, 7/12/1.5))
    """

    requires = raw"\RequirePackage{luatex85}"

    string = """
    \\nopagecolor{}
    $(fontsize(textsize, lineheight))\\selectfont
    \\color{maincolor}
    """ *  String(lstr)

    return CachedTeX(
        TeXDocument(
            string, true;
            requires = requires,
            preamble = preamble,
            class = "standalone",
            classoptions = "tightpage, margin=1pt"
        )
    )
end

# function _plottable_cachedtex_from_array(lstrs::Vector{LaTeXString}, fonts, textsizes, lineheights, colors)
#     broadcast_foreach(lstrs, fonts, textsizes, lineheights, colors) do lstr, font, textsize, lineheight, color
#         preamble *= "\n\\DeclareMathSizes{$(textsize)}{$(textsize + .5)}{$(textsize*7/12)}{$(textsize*7/12)}\n"
# end
#
#
# function latex_preamble_from_font(font)
#     family = familyname(font)
#     if family == "Noto Sans"
#     elseif family == "Fira Sans"
#     elseif family == "TeX Gyre Heros"
#     end
# end

# Helper functions to help
to_array(f::AbstractVector) = f
to_array(f::T) where T <: Makie.VecTypes = T[f]
to_array(f::T) where T = T[f]

to_narray(f::AbstractVector, n::Int) = length(f) == n ? f : fill(f, n)
to_narray(f::T) where T <: Makie.VecTypes = fill(f, n)
to_narray(f::T) where T = length(f) == n ? f : fill(f, n)


function Makie.plot!(t::Makie.Text{<: Tuple{<: CachedTeX}})
    teximg!(
        t, lift(to_array, t[1]);
        space = t.space, position=@lift([$(t.position)]), align = t.align,
        rotations = @lift([$(t.rotation)]), visible = t.visible,
        scale = 1, render_density = TEXT_RENDER_DENSITY[],
    )
end


function Makie.plot!(t::Makie.Text{<: Tuple{<:AbstractVector{<:CachedTeX}}})
    teximg!(
        t, t[1];
        space = t.space, position=t.position, align = t.align,
        rotations = lift(to_array, t.rotation), visible = t.visible,
        scale = 1, render_density = TEXT_RENDER_DENSITY[],
    )
end

function Makie.plot!(t::Makie.Text{<: Tuple{<:TeXDocument}})
    plottable_cached_tex = lift(to_array ∘ CachedTeX, t[1])

    teximg!(
        t, plottable_cached_tex;
        space = t.space, position=lift(to_array, t.position), align = t.align,
        rotations = lift(to_array, t.rotation), visible = t.visible,
        scale = 1, render_density = TEXT_RENDER_DENSITY[], )
end

function Makie.plot!(t::Makie.Text{<: Tuple{<: AbstractVector{<: TeXDocument}}})
    plottable_cached_texs = lift(t[1]) do ltexs
        ct = CachedTeX.(ltexs)
    end

    teximg!(
        t, plottable_cached_texs;
        space = t.space, position = position, align = t.align,
        rotations = t.rotation, visible = t.visible,
        scale=1, render_density=TEXT_RENDER_DENSITY[]
    )
end

################################################################################
#                              ☠️   Real Piracy 🦜                              #
################################################################################

# Here, we pirate the Makie functions which plot LaTeXString text using
# MathTeXEngine.jl and make them use MakieTeX's handling routines.
# This means that once MakieTeX is loaded, there is no way to go back to
# MathTeXEngine!
# A future solution for this would be to have some global render mode which decides
# which path is taken, but that would have to be done in Makie itself.

function Makie.plot!(t::Makie.Text{<: Tuple{<:LaTeXString}})
    plottable_cached_tex = lift(t[1], t.font, t.textsize, t.lineheight, t.color) do ltex, font, textsize, lineheight, color
        CachedTeX[to_plottable_cachedtex(ltex, font, textsize, lineheight, to_color(color))]
    end

    teximg!(t, plottable_cached_tex; position=lift(to_array, t.position), scale = 1, render_density = TEXT_RENDER_DENSITY[], align = t.align, rotations = t.rotation, visible = t.visible)
end

function Makie.plot!(t::Makie.Text{<: Tuple{<: AbstractVector{<: LaTeXString}}})
    old_ltex = Ref(t[1][])

    plottable_cached_texs = Observable{Vector{CachedTeX}}()
    onany(t[1], t.font, t.textsize, t.lineheight, t.color) do ltexs, font, textsize, lineheight, color
        if !(ltexs == old_ltex)
            plottable_cached_texs.val = to_plottable_cachedtex.(ltexs, font, textsize, lineheight, to_color(color))
            notify(plottable_cached_texs)
            old_ltex[] = ltexs
        else
            return
        end

    end
    t.font[] = t.font[]

    teximg!(
        t, plottable_cached_texs;
        position = t.position, align = t.align, rotations = t.rotation,
        visible = t.visible, scale = 1, render_density = TEXT_RENDER_DENSITY[]
    )
end


# Define bounding box methods for all extended plot types

function Makie.boundingbox(x::Makie.Text{<:Tuple{<:CachedTeX}})
    Makie.boundingbox(
        x[1][],
        to_ndim(Point3f, x.position[], 0),
        x.rotation[],
        to_value(get(x.attributes, :scale, 1)),
        x.align[]
    )
end

function Makie.boundingbox(x::Makie.Text{<:Tuple{<:AbstractArray{<:CachedTeX}}})
    Makie.boundingbox(
        x[1][],
        to_ndim.(Point3f, x.position[], 0),
        x.rotation[],
        to_value(get(x.attributes, :scale, 1)),
        x.align[]
    )
end

function Makie.boundingbox(x::Makie.Text{<:Tuple{<:Union{LaTeXString, TeXDocument}}})
    Makie.boundingbox(
        x.plots[1][1][],
        to_ndim(Point3f, x.position[], 0),
        x.rotation[],
        to_value(get(x.attributes, :scale, 1)),
        x.align[]
    )
end

function Makie.boundingbox(x::Makie.Text{<:Tuple{<:AbstractArray{<:Union{LaTeXString, TeXDocument}}}})
    Makie.boundingbox(
        x.plots[1][1][],
        to_ndim.(Point3f, x.position[], 0),
        x.rotation[],
        to_value(get(x.attributes, :scale, 1)),
        x.align[]
    )
end

# Re-direct and allow our methods to pick these up
function Makie.boundingbox(x::Makie.Text{<:Tuple{<:AbstractArray{<: Tuple{<:T, <:Point}}}}) where T <: AbstractString
    return Makie.boundingbox(x.plots[1])
end
