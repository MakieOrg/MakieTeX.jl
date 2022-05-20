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
    # attach a function to any text that calculates the glyph layout and stores it
    tex_plots = TeXImg[]
    lift(plot[1]) do cachedtexs
        delete!.(Ref(plot), tex_plots)
        empty!(tex_plots)
        sizehint!(tex_plots, length(cachedtexs))
        for (i, cachedtex) in enumerate(cachedtexs)
            if plot.rotation[] isa AbstractVector
                rotation = @lift($(plot.rotation)[i])
            else
                rotation = plot.rotation
            end

            push!(
                tex_plots,
                teximg!(plot, cachedtex; space = plot.space[], position = @lift($(plot.position)[i]), align = plot.align, rotation = rotation)
            )
        end
    end
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
    teximg!(t, t[1]; space = t.space, position=t.position, scale = 1, render_density = 5, align = t.align, rotation = t.rotation, visible = t.visible)
end


function Makie.plot!(t::Makie.Text{<: Tuple{<:AbstractVector{<:CachedTeX}}})
    teximgcollection!(t, t[1]; space = t.space, position=t.position, scale = 1, render_density = 5, align = t.align, rotation = t.rotation, visible = t.visible)
end

function Makie.plot!(t::Makie.Text{<: Tuple{<:TeXDocument}})
    plottable_cached_tex = lift(CachedTeX, t[1])

    teximg!(t, plottable_cached_tex; space = t.space, position=t.position, scale = 1, render_density = 5, align = t.align, rotation = t.rotation, visible = t.visible)
end

function Makie.plot!(t::Makie.Text{<: Tuple{<: AbstractVector{<: TeXDocument}}})
    plottable_cached_texs = lift(t[1]) do ltexs
        return CachedTeX.(ltexs)
    end

    teximgcollection!(t, plottable_cached_texs; space = t.space, position = t.position, scale=1, render_density=5, align = t.align, rotation = t.rotation, visible = t.visible)
end

"Call this function to replace the standard LaTeXString rendering with true TeX rendering!"
function hijack_latexstrings!()
    @eval begin
        function Makie.plot!(t::Makie.Text{<: Tuple{<:LaTeXString}})
            plottable_cached_tex = lift(to_plottable_cachedtex, t[1], t.font, t.textsize, t.lineheight, t.color)

            teximg!(t, Makie.Observables.async_latest(plottable_cached_tex); position=t.position, scale = 1, render_density = 5, align = t.align, rotation = t.rotation, visible = t.visible)
        end

        function Makie.plot!(t::Makie.Text{<: Tuple{<: AbstractVector{<: LaTeXString}}})
            plottable_cached_texs = lift(t[1], t.font, t.textsize, t.lineheight, t.color) do ltexs, font, textsize, lineheight, color
                return to_plottable_cachedtex.(ltexs, font, textsize, lineheight, color)
            end

            teximgcollection!(t, Makie.Observables.async_latest(plottable_cached_texs); position = t.position, align = t.align, rotation = t.rotation, visible = t.visible)
        end
    end
end
