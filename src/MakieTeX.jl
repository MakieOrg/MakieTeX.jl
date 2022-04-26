module MakieTeX
using Makie, CairoMakie, Makie.MakieLayout
using Rsvg, Cairo
using Colors, LaTeXStrings

using Makie.GeometryBasics: origin, widths
using Makie.Observables

using Poppler_jll, Perl_jll, Ghostscript_jll

include("types.jl")
include("rendering.jl")
include("recipe.jl")
include("layoutable.jl")

export TeXDocument, CachedTeX
export dvi2svg, latex2dvi, rsvg2recordsurf, svg2rsvg
export teximg, teximg!, TeXImg
export LTeX

end # document
