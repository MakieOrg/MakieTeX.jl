module MakieTeX

using Makie

using Colors, LaTeXStrings
using Base64

# Patch for Makie.jl `@Block` macro error
using Makie: make_block_docstring
using Makie: CURRENT_DEFAULT_THEME

using Makie.GeometryBasics: origin, widths
using Makie.Observables
using DocStringExtensions

using Poppler_jll, Ghostscript_jll, Glib_jll
using Rsvg, Cairo

# Default margins for `pdfcrop`.  Private, try not to touch!
const _PDFCROP_DEFAULT_MARGINS = Ref{Vector{UInt8}}([0, 0, 0, 0])
"Default density when rendering images"
const RENDER_DENSITY = Ref(3)


include("types.jl")

include("rendering/pdf_utils.jl")
include("rendering/pdf.jl")
include("rendering/svg.jl")

include("pdf_text_handler.jl")
include("latex_handler.jl")
include("typst_handler.jl")

export Cached
export TypstDocument, CachedTypst
export PDFDocument, CachedPDF
export SVGDocument, CachedSVG
export dvi2svg, latex2dvi, rsvg2recordsurf, svg2rsvg
export LaTeX, FullLaTeX
export Typst, FullTypst

export LaTeXStrings, LaTeXString, latexstring, @L_str

end # module
