module MakieTeX
using AbstractPlotting, Makie
using Rsvg, Cairo

struct TeXDocument

    "Packages to be loaded in the very beginning of the document, before `\\documentclass`."
    requires::String

    "The preamble of the document.  Goes before `\\begin{document}` but after `\\documentclass`."
    preamble::String

    "The document class and options to be passed to it."
    class::Tuple{String, String}

    "The content of the document."
    content::String

    "The handle of the rendered document."
    handle::Rsvg.RsvgHandle

end

function TeXDocument(math::String)
    return TeXDocument(

    )

function implant_math(str)
    """
    \\RequirePackage{luatex85}
    \\documentclass[preview, tightpage]{standalone}

    \\usepackage{amsmath, xcolor}
    \\pagestyle{empty}
    \\begin{document}
    \\($str\\)
    \\end{document}
    """
end

include("rendering.jl")

include("recipe.jl")

export dvi2svg, latex2dvi, rsvg2recordsurf, svg2rsvg

end # document
