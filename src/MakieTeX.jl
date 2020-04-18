module MakieTeX
using AbstractPlotting, CairoMakie, MakieLayout
using Rsvg, Cairo
using Colors, LaTeXStrings

using AbstractPlotting.GeometryBasics: origin, widths
using AbstractPlotting.Observables

include("types.jl")
include("rendering.jl")
include("recipe.jl")
include("layoutable.jl")

export dvi2svg, latex2dvi, rsvg2recordsurf, svg2rsvg
export teximg, teximg!, TeXImg
end # document
