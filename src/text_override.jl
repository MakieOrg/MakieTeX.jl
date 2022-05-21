# Here, we override the plotting function for Text
# to plot a TeXImg for either a TeXDocument or a CachedTeX
# passed in.

# First, we define a recipe for a "TeXImgCollection"
# which takes in a vector of CachedTeX

@recipe(TeXImgCollection, texs) do scene
    merge(
        default_theme(scene),
        Attributes(
            color = Makie.automatic,
            implant = true,
            render_density = 1,
            align = (:center, :center),
            scale = 1.0,
            position = Point3{Float32}(0),
            rotation = 0f0,
            space = :data,
            use_main_font=false,
        )
    )
end

function Makie.plot!(plot::T) where T <: TeXImgCollection

    tex_plots = TeXImg[]
    position_obs  = Observable[]

    onany(plot[1]; priority = 99) do cachedtexs, _
        delete!.(Ref(plot), tex_plots)
        empty!(tex_plots)

        Makie.Observables.off.(Ref(plot.position), position_obs)
        empty!(position_obs)

        sizehint!(tex_plots,    length(cachedtexs))
        sizehint!(position_obs, length(cachedtexs))
        for (i, cachedtex) in enumerate(cachedtexs)
            if plot.rotation[] isa AbstractVector
                rotation = @lift($(plot.rotation)[i])
            else
                rotation = plot.rotation
            end

            position_i = Observable{Point3f}(Point3f(0f0))
            on(plot.position) do pos
                position_i[] = pos[i]
            end

            push!(
                tex_plots,
                teximg!(plot, cachedtex; space = plot.space[], position = position_i, align = plot.align, rotation = rotation)
            )
            push!(position_obs, position_i)
        end
    end
    # update plot once
    plot[1][] = plot[1][]
    plot.position[] = plot.position[]
    plot
end

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

function Makie.plot!(t::Makie.Text{<: Tuple{<: CachedTeX}})
    teximg!(
        t, t[1];
        space = t.space, position=t.position, align = t.align,
        rotation = t.rotation, visible = t.visible,
        scale = 1, render_density = 5,
    )
end


function Makie.plot!(t::Makie.Text{<: Tuple{<:AbstractVector{<:CachedTeX}}})
    teximgcollection!(
        t, t[1];
        space = t.space, position=t.position, align = t.align,
        rotation = t.rotation, visible = t.visible,
        scale = 1, render_density = 5,
    )
end

function Makie.plot!(t::Makie.Text{<: Tuple{<:TeXDocument}})
    position = Observable(t.position[])
    plottable_cached_tex = lift(CachedTeX, t[1])

    teximg!(
        t, plottable_cached_tex;
        space = t.space, position=position, align = t.align,
        rotation = t.rotation, visible = t.visible,
        scale = 1, render_density = 5, )
end

function Makie.plot!(t::Makie.Text{<: Tuple{<: AbstractVector{<: TeXDocument}}})
    position = Observable(t.position[])
    plottable_cached_texs = lift(t[1]) do ltexs
        ct = CachedTeX.(ltexs)
        position[] = t.position[]
    end

    teximgcollection!(
        t, plottable_cached_texs;
        space = t.space, position = position, align = t.align,
        rotation = t.rotation, visible = t.visible,
        scale=1, render_density=5
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
    position = Observable(t.position[])
    plottable_cached_tex = lift(t[1], t.font, t.textsize, t.lineheight, t.color) do ltex, font, textsize, lineheight, color
        ltex = to_plottable_cachedtex(ltex, font, textsize, lineheight, color)
        position[] = t.position[]
        return ltex
    end

    teximg!(t, plottable_cached_tex; position=position, scale = 1, render_density = 5, align = t.align, rotation = t.rotation, visible = t.visible)
end

function Makie.plot!(t::Makie.Text{<: Tuple{<: AbstractVector{<: LaTeXString}}})
    position = Observable(t.position[])
    old_ltex = Ref(t[1][])

    plottable_cached_texs = Observable{Vector{CachedTeX}}()
    onany(t[1], t.position, t.font, t.textsize, t.lineheight, t.color) do ltexs, lposition, font, textsize, lineheight, color
        if !(ltexs == old_ltex)
            position[] = lposition
            plottable_cached_texs.val = to_plottable_cachedtex.(ltexs, font, textsize, lineheight, color)
            notify(plottable_cached_texs)
            old_ltex[] = ltexs
        else
            position[] = lposition
        end

    end
    t.font[] = t.font[]

    teximgcollection!(t, plottable_cached_texs; position = position, align = t.align, rotation = t.rotation, visible = t.visible)
end
