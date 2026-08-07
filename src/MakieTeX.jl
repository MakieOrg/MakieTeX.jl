module MakieTeX

using Makie

using Colors, LaTeXStrings
using Base64

using Makie: make_block_docstring
using Makie: CURRENT_DEFAULT_THEME
using Makie.GeometryBasics: origin, widths
using Makie.Observables
using DocStringExtensions

using Poppler_jll, Ghostscript_jll, Glib_jll, Librsvg_jll
using Cairo

const _PDFCROP_DEFAULT_MARGINS = Ref{Vector{UInt8}}([0, 0, 0, 0])

include("types.jl")

include("rendering/pdf_utils.jl")
include("rendering/pdf.jl")
include("rendering/svg.jl")

include("pdf_text_handler.jl")
include("latex_handler.jl")
include("typst_handler.jl")

export PDF, SVG
# `LaTeX` and `Typst` are too generic to export; access them as
# `MakieTeX.LaTeX` / `MakieTeX.Typst` (Typstry also exports a `Typst` symbol,
# so leaving them unexported avoids the ambiguity).

export LaTeXStrings, LaTeXString, latexstring, @L_str

end # module
