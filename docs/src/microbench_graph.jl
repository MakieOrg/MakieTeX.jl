# Initial code by `@tecosaur` and `@asinghvi17` on 2024-04-07.  Contributions and edits by `@asinghvi17`, `@jar`, `@LazarusA`, `@jkrumbiegel`.

using DataToolkit, DataFrames, StatsBase
using CairoMakie, SwarmMakie #=beeswarm plots=#, Colors
using MakieTeX # for SVG icons

function svg_icon(name::String)
    if name == "go"
        icon = d"go-logo-solid::IO"
    else
        path = "svg/$name.svg"
        icon = get(d"file-icons::Dict{String,IO}", path, nothing)
    end
    if isnothing(icon)
        icon = get(d"file-icons-mfixx::Dict{String,IO}", path, nothing)
    end
    if isnothing(icon)
        icon = get(d"file-icons-devopicons::Dict{String,IO}", path, nothing)
    end
    isnothing(icon) && return missing
    return CachedSVG(read(seekstart(icon), String))
end

const colours_vibrant = range(LCHab(60,70,0), stop=LCHab(60,70,360), length=36)
const colours_dim     = range(LCHab(25,50,0), stop=LCHab(25,50,360), length=36)

const lang_info = Dict(
    :c           => (name = "C",           icon = svg_icon("c"),           colour = 25),
    :julia       => (name = "Julia",       icon = svg_icon("Julia"),       colour = 31),
    :lua         => (name = "LuaJIT",      icon = svg_icon("Lua"),         colour = 23),
    :fortran     => (name = "Fortran",     icon = svg_icon("Fortran"),     colour = 33),
    :javascript  => (name = "JavaScript",  icon = svg_icon("javascript"),  colour = 7),
    :java        => (name = "Java",        icon = svg_icon("java"),        colour = 14),
    :matlab      => (name = "Matlab",      icon = svg_icon("MATLAB"),      colour = 5),
    :mathematica => (name = "Mathematica", icon = svg_icon("Mathematica"), colour = 4),
    :python      => (name = "Python",      icon = svg_icon("python"),      colour = 17),
    :octave      => (name = "Octave",      icon = svg_icon("Octave"),      colour = 9),
    :r           => (name = "R",           icon = svg_icon("R"),           colour = 28),
    :rust        => (name = "Rust",        icon = svg_icon("rust"),        colour = 6),
    :go          => (name = "Go",          icon = svg_icon("go"),          colour = 21)
)

const microbench = sort(unstack(d"microbench", :language, :benchmark, :time),
                        :language, by=l->lang_info[Symbol(l)].colour, rev=true)

for (col, cval) in pairs(microbench[findfirst(microbench.language .== "c"), :])
    col == :language && continue
    microbench[!, col] ./= cval
end

# const lang_geomeans = Pair{String, Float64}[]

const plot_data = (
    bench_name = String[],
    xs = Int[],
    ys = Union{Float64, Missing}[],
    markers = CachedSVG[],
    colours = Colorant[],
    langs = Makie.RichText[],
    lang_markers = MarkerElement[],
    lang_colours = Colorant[],
)

for (i, row) in enumerate(Tables.namedtupleiterator(
    unstack(stack(microbench), :variable, :language, :value)))
    bench_name, results... = values(row)
    _, langs... = keys(row)
    push!(plot_data.bench_name, replace(bench_name, '_' =>' ') |> titlecase)
    append!(plot_data.xs, fill(i, length(results)))
    append!(plot_data.ys, results)
    for lang in langs
        linfo = lang_info[lang]
        push!(plot_data.markers, linfo.icon)
        push!(plot_data.colours, colours_vibrant[linfo.colour])
        if i == 1
            push!(plot_data.langs, Makie.rich(linfo.name, color = colours_dim[linfo.colour]))
            push!(plot_data.lang_markers,
                  MarkerElement(marker = linfo.icon, color = colours_vibrant[linfo.colour],
                                markersize = 12))
        end
    end
end

update_theme!(fonts = Attributes(
    bold = "Alegreya Sans Bold",
    bold_italic = "Alegreya Sans Bold Italic",
    italic = "Alegreya Sans Italic",
    regular = "Alegreya Sans Medium"))

fig = Figure(size = (1400, 620))
ax = Axis(fig[1,1], yscale=log10,
          title = "Programming Language Micro-Benchmarks",
          titlesize = 18,
          xticks = (1:length(plot_data.bench_name), plot_data.bench_name),
          xticksvisible = false,
          xticklabelsize = 12,
          xgridvisible=false,
          ylabel="Run time, relative to C",
          yminorticks = IntervalsBetween(5),
          yminorgridvisible = true)
hidespines!(ax)
bp = beeswarm!(ax, plot_data.xs, plot_data.ys,
          color = plot_data.colours,
          marker = plot_data.markers,
          markersize = 16)
Legend(fig[2,1], plot_data.lang_markers, plot_data.langs, "Language",
       framevisible=false, orientation = :horizontal, titleposition = :left,
       titlevalign = 1.5, labelvalign = 1.5)
# Decrease the beeswarm's internal scatter plot markersize.  
# This way, beeswarm calculations are still run with the original markersize, but the actual markers are shrunk.
only(bp.plots).markersize = 16*0.85
# Display the figure!
fig