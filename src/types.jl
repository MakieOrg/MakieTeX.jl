
struct TeXDocument
    contents::String
end

"""
    TeXDocument(contents::AbstractString, add_defaults::Bool; requires, preamble, class, classoptions)

This constructor function creates a TeX document which can be passed to `teximg`.
All arguments are to be passed as strings.

If `add_defaults` is `false`, then we will *not* automatically add document structure.
Note that in this case, keyword arguments will be disregarded and `contents` must be
a complete LaTeX document.

Available keyword arguments are:
- `requires`: code which comes before `documentclass` in the preamble.  Default: `raw"\\RequirePackage{luatex85}"`.
- `class`: the document class.  Default (and what you should use): `"standalone"`.
- `classoptions`: the options you should pass to the class, i.e., `\\documentclass[\$classoptions]{\$class}`.  Default: `"preview, tightpage, 12pt"`.
- `preamble`: arbitrary code for the preamble (between `\\documentclass` and `\\begin{document}`).  Default: `raw"\\usepackage{amsmath, xcolor} \\pagestyle{empty}"`.
"""
function TeXDocument(
            contents::AbstractString,
            add_defaults::Bool;
            requires::AbstractString = raw"\RequirePackage{luatex85}",
            class::AbstractString = "standalone",
            classoptions::AbstractString = "preview, tightpage, 12pt",
            preamble::AbstractString = raw"""
                        \usepackage{amsmath, xcolor}
                        \pagestyle{empty}
                        """,
        )
        if add_defaults
            return TeXDocument(
                """
                $(requires)

                \\documentclass[$(classoptions)]{$(class)}

                $(preamble)

                \\begin{document}

                $(contents)

                \\end{document}
                """
            )
        else
            return TeXDocument(contents)
        end
end

"""
    texdoc(contents::AbstractString; kwargs...)

A shorthand for `TeXDocument(contents, add_defaults=true; kwargs...)`.

Available keyword arguments are:

- `requires`: code which comes before `documentclass` in the preamble.  Default: `raw"\\RequirePackage{luatex85}"`.
- `class`: the document class.  Default (and what you should use): `"standalone"`.
- `classoptions`: the options you should pass to the class, i.e., `\\documentclass[\$classoptions]{\$class}`.  Default: `"preview, tightpage, 12pt"`.
- `preamble`: arbitrary code for the preamble (between `\\documentclass` and `\\begin{document}`).  Default: `raw"\\usepackage{amsmath, xcolor} \\pagestyle{empty}"`.

"""
texdoc(contents; kwargs...) = TeXDocument(contents, true; kwargs...)

function Base.convert(::Type{String}, doc::TeXDocument)
    return Base.convert(String, doc.contents)
end

struct CachedTeX
    doc::TeXDocument
    handle::Rsvg.RsvgHandle
    raw_dims::Rsvg.RsvgDimensionData
    svg::String
end

"""
    CachedTeX(doc::TeXDocument, dpi = 72.0; kwargs...)

Compile a `TeXDocument`, compile it and return the cached TeX object.

A `CachedTeX` struct stores the document, the Rsvg handle, the Rsvg dimensions
and the SVG as a string for error checking.

In `kwargs`, one can pass anything which goes to the internal function `compile_latex`.
These are primarily:
- `engine = \`lualatex\`/\`xelatex\`/...`: the LaTeX engine to use when rendering
- `options=\`-file-line-error\``: the options to pass to `latexmk`.
"""
function CachedTeX(doc::TeXDocument, dpi = 72.0; method = :pdf, kwargs...)
    svg = if method == :dvi
        dvi2svg(latex2dvi(convert(String, doc); kwargs...))
    elseif method == :pdf
        pdf2svg(latex2pdf(convert(String, doc); kwargs...))
    else
        @error("$method not recognized!  Must be one of (:dvi, :pdf).")
    end

    handle = svg2rsvg(svg, dpi)

    dims = Rsvg.handle_get_dimensions(handle)
    return CachedTeX(
        doc,
        handle,
        dims,
        svg
    )
end

function CachedTeX(str::String, dpi = 72.0; kwargs...)
    return CachedTeX(implant_text(str), dpi; kwargs...)
end

function CachedTeX(x::LaTeXString, dpi = 72.0; kwargs...)
    return if first(x) == "\$" && last(x) == "\$"
        CachedTeX(implant_math(x), dpi; kwargs...)
    else
        CachedTeX(implant_text(x), dpi; kwargs...)
    end
end

CachedTeX(ct::CachedTeX, dpi=72.0) = ct


# function new_cachedtex(doc::TeXDocument)
#     svg = compile_latex(convert(String, doc), format="pdf", read_format="svg")
#     handle = svg2rsvg(String(svg), 72.0)
#     dims = Rsvg.handle_get_dimensions(handle)
#     return CachedTeX(
#         doc, handle, dims, svg
#     )
# end


function Base.show(io::IO, ct::CachedTeX)
    if length(ct.doc.contents) > 1000
        println(io, "CachedTeX(TexDocument(...), $(ct.handle), $(ct.raw_dims))")
    else
        println(io, "CachedTeX($(ct.doc), $(ct.handle), $(ct.raw_dims))")
    end
end

function implant_math(str)
    return TeXDocument(
        """\\(\\displaystyle $str\\)""", true;
        requires = "\\RequirePackage{luatex85}",
        preamble = """
        \\usepackage{amsmath, xcolor}
        \\pagestyle{empty}
        """,
        class = "standalone",
        classoptions = "preview, tightpage, 12pt",
    )
end

function implant_text(str)
    return TeXDocument(
        str, true;
        requires = "\\RequirePackage{luatex85}",
        preamble = """
        \\usepackage{amsmath, xcolor}
        \\pagestyle{empty}
        """,
        class = "standalone",
        classoptions = "preview, tightpage, 12pt"
    )
end
