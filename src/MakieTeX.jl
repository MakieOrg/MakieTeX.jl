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

end

function Base.convert(::Type{String}, doc::TeXDocument)
    return """
    $(doc.requires)

    \\documentclass[$(doc.class[2])]{$(doc.class[1])}

    $(doc.preamble)

    \\begin{document}

    $(doc.content)

    \\end{document}
    """
end

struct CachedTeX
    doc::TeXDocument
    handle::Rsvg.RsvgHandle
    raw_dims::Rsvg.RsvgDimensionData
end

function CachedTeX(doc::TeXDocument)
    handle = svg2rsvg(dvi2svg(latex2dvi(convert(String, doc))))
    dims = Rsvg.get_handle_dims(handle)
    return CachedTeX(
        doc,
        handle,
        dims
    )
end

function implant_math(str)
    return TeXDocument(
        "\\RequirePackage{luatex85}",
        """
        \\usepackage{amsmath, xcolor}
        \\pagestyle{empty}
        """,
        ("standalone", "preview, tightpage"),
        """
        \\( \\displaystyle
            $str
        \\)
        """
    ) |> String
end

include("rendering.jl")

include("recipe.jl")

export dvi2svg, latex2dvi, rsvg2recordsurf, svg2rsvg

end # document
