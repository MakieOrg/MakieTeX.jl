module MakieTeX
using AbstractPlotting, CairoMakie, MakieLayout
using Rsvg, Cairo, LaTeXStrings
using Colors

using AbstractPlotting.GeometryBasics: origin, widths
using AbstractPlotting.Observables

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
    svg::String
end

function CachedTeX(doc::TeXDocument)
    svg = dvi2svg(latex2dvi(convert(String, doc)))
    handle = svg2rsvg(svg)
    dims = Rsvg.handle_get_dimensions(handle)
    return CachedTeX(
        doc,
        handle,
        dims,
        svg
    )
end

function CachedTeX(str::String)
    return CachedTeX(implant_math(str))
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
    )
end

function implant_text(str)
    return TeXDocument(
        "\\RequirePackage{luatex85}",
        """
        \\usepackage{amsmath, xcolor}
        \\pagestyle{empty}
        """,
        ("standalone", "preview, tightpage"),
        str
    )
end

include("rendering.jl")

include("recipe.jl")

include("layoutable.jl")

export dvi2svg, latex2dvi, rsvg2recordsurf, svg2rsvg
export teximg, teximg!, TeXImg
end # document
