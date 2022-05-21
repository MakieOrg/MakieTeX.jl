# Here, we override the plotting function for Text
# to plot a TeXImg for either a TeXDocument or a CachedTeX
# passed in.
# The main theme-enabled function, which takes in information from multiple places
# and spreads them out!
function to_plottable_cachedtex(lstr, font, textsize, lineheight, color)
    # $(usemain && raw"\usepackage{fontspec}")
    preamble = """

    \\usepackage{lmodern}
    \\usepackage[T1]{fontenc}
    \\usepackage{amsmath, amssymb, amsfonts, xcolor, tikz}
    \\definecolor{maincolor}{HTML}{$(Makie.Colors.hex(RGBf(color)))}
    \\DeclareMathSizes{$(textsize)}{$(textsize + .5)}{$(textsize*7/12)}{$(textsize*7/12)}
    """

    requires = raw"\RequirePackage{luatex85}"

    string = """
    \\nopagecolor{}
    \\fontsize{$(textsize)}{$(round(Int, textsize * lineheight))}\\selectfont
    \\color{maincolor}
    """ *  String(lstr)

    return CachedTeX(TeXDocument(string, true; requires = requires, preamble = preamble))
end

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
    teximgcollection!(
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
