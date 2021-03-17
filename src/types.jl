
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

function TeXDocument(
            math::AbstractString;
            requires = raw"\RequirePackage{luatex85}",
            preamble = raw"""
                        \usepackage{amsmath, xcolor}
                        \pagestyle{empty}
                        """,
            class = "standalone",
            classoptions = "preview, tightpage, 12pt"
        )
        return TeXDocument(
            requires,
            preamble,
            (class, classoptions),
            math
        )
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

function CachedTeX(doc::TeXDocument, dpi = 72.0)
    svg = dvi2svg(latex2dvi(convert(String, doc)))
    handle = svg2rsvg(svg, dpi)
    dims = Rsvg.handle_get_dimensions(handle)
    return CachedTeX(
        doc,
        handle,
        dims,
        svg
    )
end

function CachedTeX(str::String, dpi = 72.0)
    return CachedTeX(implant_math(str), dpi)
end

function CachedTeX(x::LaTeXString, dpi = 72.0)
    return if first(x) == "\$" && last(x) == "\$"
        CachedTeX(implant_math(x), dpi)
    else
        CachedTeX(implant_text(x), dpi)
    end
end

function implant_math(str)
    return TeXDocument(
        "\\RequirePackage{luatex85}",
        """
        \\usepackage{amsmath, xcolor}
        \\pagestyle{empty}
        """,
        ("standalone", "preview, tightpage, 12pt"),
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
        ("standalone", "preview, tightpage, 12pt"),
        str
    )
end
