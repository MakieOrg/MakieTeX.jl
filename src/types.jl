#=
# MakieTeX types

This file defines types and APIs for MakieTeX.  

The API starts with the `AbstractDocument` type, which is the supertype of all vector documents.  
An `AbstractDocument` must contain a document as a String or Vector{UInt8} of the full contents 
of whichever file it is using.  It may contain additional fields - for example, `PDFDocument`s 
contain a page number to indicate which page to display, in the case where a PDF has multiple pages.

Cached documents are "loaded" versions of AbstractDocuments, and store a pointer/reference to the 
loaded version of the document (a Poppler handle for PDFs, or Rsvg handle for SVGs).  

They also contain a Cairo surface to which the document has been rendered, as well as a cache of a 
rasterized PNG and its scale for performance reasons.  See the documentation of [`rasterize`](@ref)
for more.
=#

"""
    abstract type AbstractDocument

An `AbstractDocument` must contain a document as a String or Vector{UInt8} of the full contents 
of whichever file it is using.  It may contain additional fields - for example, `PDFDocument`s 
contain a page number to indicate which page to display, in the case where a PDF has multiple pages.
        
`AbstractDocument`s must implement the following functions:
- `getdoc(doc::AbstractDocument)::Union{Vector{UInt8}, String}`
- `mimetype(doc::AbstractDocument)::Base.MIME`
- `Cached(doc::AbstractDocument)::AbstractCachedDocument`
"""
abstract type AbstractDocument end

"""
    getdoc(doc::AbstractDocument)::Union{Vector{UInt8}, String}

Return the document data (contents of the file) as a `Vector{UInt8}` or `String`.
This must be the full file, i.e., if it was saved, the file should be immediately openable.
"""
function getdoc end
"""
    mimetype(::Type{<: AbstractDocument})::Base.MIME
    mimetype(::AbstractDocument)::Base.MIME

Return the MIME type of the document.  For example, `mimetype(::SVGDocument) == MIME("image/svg+xml")`.

!!! note
    This is generally defined for the type, and there is a 
    generic overload when passing a constructed object.
"""
function mimetype end
"""
    Cached(doc::AbstractDocument)::AbstractCachedDocument

Generic interface to cache a document and return it.
"""
function Cached end

"""
    abstract type AbstractCachedDocument

Cached documents are "loaded" versions of AbstractDocuments, and store a pointer/reference to the 
loaded version of the document (a Poppler handle for PDFs, or Rsvg handle for SVGs).  

They also contain a Cairo surface to which the document has been rendered, as well as a cache of a 
rasterized PNG and its scale for performance reasons.  See the documentation of [`rasterize`](@ref)
for more.

`AbstractCachedDocument`s must implement the [`AbstractDocument`](@ref) API, as well as the following:
- `rasterize(doc::AbstractCachedDocument, [scale::Real = 1])::Matrix{ARGB32}`
- `draw_to_cairo_surface(doc::AbstractCachedDocument, surf::CairoSurface)`
- `update_handle!(doc::AbstractCachedDocument)::<some_handle_type>`
"""
abstract type AbstractCachedDocument <: AbstractDocument end


"""
    rasterize(doc::AbstractCachedDocument, scale::Real = 1)

Render a `CachedDocument` to an image at a given scale.  This is a convenience function which
calls the appropriate rendering function for the document type.  Returns an image as a `Matrix{ARGB32}`.
"""
function rasterize end

"""
    draw_to_cairo_surface(doc::AbstractCachedDocument, surf::CairoSurface)

Render a `CachedDocument` to a Cairo surface.  This is a convenience function which
calls the appropriate rendering function for the document type.
"""
function draw_to_cairo_surface end

"""
    update_handle!(doc::AbstractCachedDocument)

Update the internal handle/pointer to the loaded document in a `CachedDocument`, and returns it.

This function is used to refresh the handle/pointer to the loaded document in case it has been
garbage collected or invalidated. It should return the updated handle/pointer.

For example, in `CachedPDF`, this function would reload the PDF document using the `doc.doc` field
and update the `ptr` field with the new Poppler handle, **if it is found to be invalid**.

Note that this function needs to be implemented for each concrete subtype of `AbstractCachedDocument`,
as the handle/pointer type and the method to load/update it will be different for different document
types (e.g., PDF, SVG, etc.).
"""
function update_handle! end

Cached(doc::AbstractCachedDocument) = doc

#=

## Generic dispatches for documents

Define generic functions for all AbstractDocuments, with special emphasis on Makie 
compatibility and conversions.

### Generic dispatches

=#

mimetype(::T) where T <: AbstractDocument = mimetype(T)

Base.convert(::Type{String}, doc::AbstractDocument) = Base.convert(String, getdoc(doc))
Base.convert(::Type{UInt8}, doc::AbstractDocument) = Vector{UInt8}(Base.convert(String, doc))

Base.convert(::Type{Matrix{T}}, doc::AbstractDocument) where T <: Colors.Color = T.(Base.convert(Matrix{ARGB32}, doc))
Base.convert(::Type{Matrix{ARGB32}}, doc::AbstractDocument) = Base.convert(Matrix{ARGB32}, Cached(doc))
Base.convert(::Type{Matrix{ARGB32}}, cached::AbstractCachedDocument) = rasterize(doc)

Base.size(cached::AbstractCachedDocument) = cached.dims

#=
### Convert arbitrary Julia objects to Documents

TODOs: 
- Allow the conversion to use the constructor, if there is a method.
=#


function Base.convert(T::Type{<: AbstractDocument}, x)
    if !showable(mimetype(T), x)
        error("Object of type $(typeof(x)) is not showable as mime type $(mimetype(T)).")
    end
    return T(sprint(show, mimetype(T), x))
end
# This resolves an ambiguity otherwise.
Base.convert(::Type{T}, x::T) where T <: AbstractDocument = x

function Base.convert(::Type{AbstractDocument}, x)
    for DocType in [TEXDocument, TypstDocument, SVGDocument, PDFDocument]
        if showable(mimetype(DocType), x)
            return convert(DocType, x)
        end
    end
    error("MakieTeX: Object of type $(typeof(x)) is not showable as an AbstractDocument.")
end


function Base.convert(::Type{AbstractCachedDocument}, x)
    for DocType in [CachedTEX, CachedTypst, CachedSVG, CachedPDF]
        if showable(mimetype(DocType), x)
            return convert(DocType, x)
        end
    end
    error("MakieTeX: Object of type $(typeof(x)) is not showable as an AbstractCachedDocument.")
end

#=

### Makie.jl function definitions
The backend-specific functions and rasterizers are kept in the backends' extensions.

These functions are generic to the Makie API.
=#
Makie.to_spritemarker(x::AbstractCachedDocument) = rasterize(x, MakieTeX.RENDER_DENSITY[])
Makie.marker_to_sdf_shape(::AbstractCachedDocument) = Makie.RECTANGLE # this is the same result as the dispatch for `::AbstractMatrix`.
Makie.el32convert(x::AbstractCachedDocument) = rasterize(x, MakieTeX.RENDER_DENSITY[])

Makie.to_spritemarker(x::AbstractDocument) = rasterize(Cached(x), MakieTeX.RENDER_DENSITY[]) # this should never be called

#=
## Concrete type definitions

Now, we define the structs which hold the documents and their cached versions.

### Raw documents
=#

"""
    SVGDocument(svg::AbstractString)

A document type which stores an SVG string.

Is converted to [`CachedSVG`](@ref) for use in plotting.
"""
struct SVGDocument <: AbstractDocument
    doc::String
end
Cached(x::SVGDocument) = CachedSVG(x)
getdoc(doc::SVGDocument) = doc.doc
mimetype(::Type{SVGDocument}) = MIME"image/svg+xml"()

"""
    PDFDocument(pdf::AbstractString, [page = 0])

A document type which holds a raw PDF as a string.

Is converted to [`CachedPDF`](@ref) for use in plotting.
"""
struct PDFDocument <: AbstractDocument
    doc::String
    page::Int
end
PDFDocument(doc::String) = PDFDocument(doc, 0)
PDFDocument(doc::Vector{UInt8}) = PDFDocument(String(doc))
Cached(x::PDFDocument) = CachedPDF(x)
getdoc(doc::PDFDocument) = doc.doc
mimetype(::Type{PDFDocument}) = MIME"application/pdf"()

"""
    EPSDocument(eps::AbstractString, [page = 0])

A document type which holds an EPS string.

Is converted to [`CachedPDF`](@ref) for use in plotting.
"""
struct EPSDocument <: AbstractDocument
    doc::String
    page::Int
end
EPSDocument(doc::String) = EPSDocument(doc, 0) # default page is 0
Cached(x::EPSDocument) = CachedPDF(x)
getdoc(doc::EPSDocument) = doc.doc
mimetype(::Type{EPSDocument}) = MIME"application/postscript"()

# This will be documented elsewhere in the package.
struct TEXDocument <: AbstractDocument
    contents::String
    page::Int
end
TEXDocument(contents) = TEXDocument(contents, 0)
Cached(x::TEXDocument) = CachedTEX(x)
getdoc(doc::TEXDocument) = doc.contents
mimetype(::Type{TEXDocument}) = MIME"text/latex"()

Base.@deprecate TeXDocument TEXDocument # To keep consistency, we deprecate the TeX in favour of TEX.  This will require a large refactor everywhere, but should be worth it.

"""
    TEXDocument(contents::AbstractString, add_defaults::Bool; requires, preamble, class, classoptions)

This constructor function creates a `struct` of type `TEXDocument` which can be passed to `teximg`.
All arguments are to be passed as strings.

If `add_defaults` is `false`, then we will *not* automatically add document structure.
Note that in this case, keyword arguments will be disregarded and `contents` must be
a complete LaTeX document.

Available keyword arguments are:
- `requires`: code which comes before `documentclass` in the preamble.  Default: `raw"\\RequirePackage{luatex85}"`.
- `class`: the document class.  Default (and what you should use): `"standalone"`.
- `classoptions`: the options you should pass to the class, i.e., `\\documentclass[\$classoptions]{\$class}`.  Default: `"preview, tightpage, 12pt"`.
- `preamble`: arbitrary code for the preamble (between `\\documentclass` and `\\begin{document}`).  Default: `raw"\\usepackage{amsmath, xcolor} \\pagestyle{empty}"`.

See also [`CachedTEX`](@ref), [`compile_latex`](@ref), etc.
"""
function TEXDocument(
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
            return TEXDocument(
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
            return TEXDocument(contents)
        end
end
# Define dispatches for things known to be LaTeX in nature
TEXDocument(l::LaTeXString) = TEXDocument(l, true)

"""
    texdoc(contents::AbstractString; kwargs...)

A shorthand for `TEXDocument(contents, add_defaults=true; kwargs...)`.

Available keyword arguments are:

- `requires`: code which comes before `documentclass` in the preamble.  Default: `raw"\\RequirePackage{luatex85}"`.
- `class`: the document class.  Default (and what you should use): `"standalone"`.
- `classoptions`: the options you should pass to the class, i.e., `\\documentclass[\$classoptions]{\$class}`.  Default: `"preview, tightpage, 12pt"`.
- `preamble`: arbitrary code for the preamble (between `\\documentclass` and `\\begin{document}`).  Default: `raw"\\usepackage{amsmath, xcolor} \\pagestyle{empty}"`.

"""
texdoc(contents; kwargs...) = TEXDocument(contents, true; kwargs...)

function Base.convert(::Type{TEXDocument}, x)
    if !showable(mimetype(TEXDocument), x)
        error("Object of type $(typeof(x)) is not showable as mime type $(mimetype(TEXDocument)).")
    end
    texstring = sprint(show, mimetype(TEXDocument), x)
    if contains(texstring, "\\begin{document}")
        return TEXDocument(texstring, false) # assume this to be a fixed document
    else
        return TEXDocument(texstring, true) # assume this to require a preamble
    end
end

struct TypstDocument <: AbstractDocument
    contents::String
    page::Int
end
TypstDocument(contents) = TypstDocument(contents, 0)
Cached(x::TypstDocument) = CachedTypst(x)
getdoc(doc::TypstDocument) = doc.contents
mimetype(::Type{TypstDocument}) = MIME"text/typst"()

"""
    TypstDocument(contents::AbstractString, add_defaults::Bool; preamble)

This constructor function creates a `struct` of type `TypstDocument`.
All arguments are to be passed as strings.

If `add_defaults` is `false`, then we will *not* automatically add document structure.
Note that in this case, keyword arguments will be disregarded and `contents` must be
a complete Typst document.

Available keyword arguments are:
- `preamble`: arbitrary code inserted prior to the `contents`.  Default: `""`.

See also [`CachedTypst`](@ref), [`compile_typst`](@ref), etc.
"""
function TypstDocument(
        contents::AbstractString,
        add_defaults::Bool;
        preamble::AbstractString = "",
    )
    if add_defaults
        return TypstDocument(
            """
            $(preamble)

            $(contents)
            """
        )
    else
        return TypstDocument(contents)
    end
end
TypstDocument(ts::TypstString) = TypstDocument(ts, true)

"""
    typstdoc(contents::AbstractString; kwargs...)

A shorthand for `TypstDocument(contents, add_defaults=true; kwargs...)`.

Available keyword arguments are:

- `preamble`: arbitrary code inserted prior to the `contents`.  Default: `""`.

"""
typst_doc(contents; kwargs...) = TypstDocument(contents, true; kwargs...)



#=
# Cached documents
=#
"""
    CachedPDF(pdf::PDFDocument)

Holds a PDF document along with a Poppler handle and a Cairo surface to which it has already 
been rendered.

## Usage

```julia
CachedPDF(read("path/to/pdf.pdf"), [page = 0])
CachedPDF(read("path/to/pdf.pdf", String), [page = 0])
CachedPDF(PDFDocument(...), [page = 0])
```

## Fields

$(FIELDS)

"""
struct CachedPDF <: AbstractCachedDocument
    "A reference to the `PDFDocument` which is cached here."
    doc::PDFDocument
    "A pointer to the Poppler handle of the PDF.  May be randomly GC'ed by Poppler."
    ptr::Ref{Ptr{Cvoid}}
    "The dimensions of the PDF page in points, for ease of access."
    dims::Tuple{Float64, Float64}
    "A Cairo surface to which Poppler has drawn the PDF.  Permanent and cached."
    surf::CairoSurface
    "A cache for a (rendered_image, scale_factor) pair.  This is used to avoid re-rendering the PDF."
    image_cache::Ref{Tuple{Matrix{ARGB32}, Float64}}
end

function CachedPDF(pdf::PDFDocument, poppler_handle::Ptr{Cvoid}, dims::Tuple{Float64, Float64}, surf::CairoSurface)
    return CachedPDF(pdf, Ref(poppler_handle), dims, surf, Ref{Tuple{Matrix{ARGB32}, Float64}}((Matrix{ARGB32}(undef, 0, 0), 0)))
end
CachedPDF(pdf::String) = CachedPDF(PDFDocument(pdf))
getdoc(doc::CachedPDF) = getdoc(doc.doc)
mimetype(::Type{CachedPDF}) = MIME"application/pdf"()


"""
    CachedSVG(svg::SVGDocument)

Holds an SVG document along with an Rsvg handle and a Cairo surface to which it has already
been rendered.

## Usage

```julia
CachedSVG(read("path/to/svg.svg"))
CachedSVG(read("path/to/svg.svg", String))
CachedSVG(SVGDocument(...))
```

## Fields

$(FIELDS)
"""
struct CachedSVG <: AbstractCachedDocument
    "The original `SVGDocument` which is cached here, i.e., the text of that SVG."
    doc::SVGDocument
    "A pointer to the Rsvg handle of the SVG.  May be randomly GC'ed by Rsvg, so is stored as a `Ref` in case it has to be refreshed."
    handle::Ref{Rsvg.RsvgHandle}
    "The dimensions of the SVG in points, for ease of access."
    dims::Tuple{Float64, Float64}
    "A Cairo surface to which Rsvg has drawn the SVG.  Permanent and cached."
    surf::CairoSurface
    "A cache for a (rendered_image, scale_factor) pair.  This is used to avoid re-rendering the PDF."
    image_cache::Ref{Tuple{Matrix{ARGB32}, Float64}}
end
function CachedSVG(svg::SVGDocument, rsvg_handle::Rsvg.RsvgHandle, dims::Tuple{Float64, Float64}, surf::CairoSurface)
    return CachedSVG(svg, Ref(rsvg_handle), dims, surf, Ref{Tuple{Matrix{ARGB32}, Float64}}((Matrix{ARGB32}(undef, 0, 0), 0)))
end
CachedSVG(svg::String) = CachedSVG(SVGDocument(svg))
getdoc(doc::CachedSVG) = getdoc(doc.doc)
mimetype(::Type{CachedSVG}) = MIME"image/svg+xml"()


# TODO: document, that you should use PDFDocument/CachedPDF.
# TeX is only special cased as a cached thing because it can be themed.
struct CachedTEX <: AbstractCachedDocument
    "The original `TEXDocument` which is compiled."
    doc::TEXDocument
    "The resulting compiled PDF"
    pdf::Vector{UInt8}
    "A pointer to the Poppler handle of the PDF.  May be randomly GC'ed by Poppler."
    ptr::Ref{Ptr{Cvoid}} # Poppler handle
    "A surface to which Poppler has drawn the PDF.  Permanent and cached."
    surf::CairoSurface
    "The dimensions of the PDF page, for ease of access."
    dims::Tuple{Float64, Float64}
end
const CachedTeX = CachedTEX
getdoc(doc::CachedTEX) = getdoc(doc.doc)
mimetype(::Type{CachedTEX}) = MIME"text/latex"()

"""
    CachedTEX(doc::TEXDocument; kwargs...)

Compile a `TEXDocument`, compile it and return the cached TeX object.

A `CachedTEX` struct stores the document and its compiled form, as well as some
pointers to in-program versions of it.  It also stores the page dimensions.

In `kwargs`, one can pass anything which goes to the internal function `compile_latex`.
These are primarily:
- `engine = \`lualatex\`/\`xelatex\`/...`: the LaTeX engine to use when rendering
- `options=\`-file-line-error\``: the options to pass to `latexmk`.

The constructor stores the following fields:
$(FIELDS)

!!! note
    This is a `mutable struct` because the pointer to the Poppler handle can change.
    TODO: make this an immutable struct with a Ref to the handle??  OR maybe even the surface itself...

!!! note
    It is also possible to manually construct a `CachedTEX` with `nothing` in the `doc` field, 
    if you just want to insert a pre-rendered PDF into your figure.
"""
CachedTEX(doc::TEXDocument; kwargs...) = cached_doc(CachedTEX, latex2pdf, doc; kwargs...)

function CachedTEX(str::String; kwargs...)
    return CachedTEX(implant_text(str); kwargs...)
end

function CachedTEX(x::LaTeXString; kwargs...)
    x = convert(String, x)
    return if first(x) == "\$" && last(x) == "\$"
        CachedTEX(implant_math(x[2:end-1]); kwargs...)
    else
        CachedTEX(implant_text(x); kwargs...)
    end
end

CachedTEX(pdf::Vector{UInt8}; kwargs...) = cached_pdf(CachedTEX, pdf; kwargs...)

# do not rerun the pipeline on CachedTEX
CachedTEX(ct::CachedTEX) = ct

struct CachedTypst <: AbstractCachedDocument
    "The original `TypstDocument` which is compiled."
    doc::TypstDocument
    "The resulting compiled PDF"
    pdf::Vector{UInt8}
    "A pointer to the Poppler handle of the PDF.  May be randomly GC'ed by Poppler."
    ptr::Ref{Ptr{Cvoid}} # Poppler handle
    "A surface to which Poppler has drawn the PDF.  Permanent and cached."
    surf::CairoSurface
    "The dimensions of the PDF page, for ease of access."
    dims::Tuple{Float64, Float64}
end
getdoc(doc::CachedTypst) = getdoc(doc.doc)
mimetype(::Type{CachedTypst}) = MIME"text/typst"()

"""
    CachedTypst(doc::TypstDocument)

Compile a `TypstDocument`, compile it and return the cached Typst object.

A `CachedTypst` struct stores the document and its compiled form, as well as some
pointers to in-program versions of it.  It also stores the page dimensions.

The constructor stores the following fields:
$(FIELDS)

!!! note
    This is a `mutable struct` because the pointer to the Poppler handle can change.
    TODO: make this an immutable struct with a Ref to the handle??  OR maybe even the surface itself...

!!! note
    It is also possible to manually construct a `CachedTypst` with `nothing` in the `doc` field, 
    if you just want to insert a pre-rendered PDF into your figure.
"""
CachedTypst(doc::TypstDocument) = cached_doc(CachedTypst, typst2pdf, doc)

function CachedTypst(str::Union{String, TypstString}; kwargs...)
    CachedTypst(TypstDocument(str); kwargs...)
end

CachedTypst(pdf::Vector{UInt8}; kwargs...) = cached_pdf(CachedTypst, pdf; kwargs...)

# do not rerun the pipeline on CachedTypst
CachedTypst(ct::CachedTypst) = ct

function cached_doc(T, f, doc; kwargs...)
    pdf = Vector{UInt8}(f(convert(String, doc); kwargs...))
    ptr = load_pdf(pdf)
    surf = page2recordsurf(ptr, doc.page)
    dims = (pdf_get_page_size(ptr, doc.page))

    ct = T(
        doc,
        pdf,
        Ref(ptr),
        surf,
        dims# .+ (1, 1),
    )

    return ct
end

function cached_pdf(T, pdf; kwargs...)
    ptr = load_pdf(pdf)
    surf = firstpage2recordsurf(ptr)
    dims = pdf_get_page_size(ptr, 0)

    ct = T(
        nothing,
        pdf,
        Ref(ptr),
        surf,
        dims# .+ (1, 1),
    )
    return ct
end

function update_handle!(ct::Union{CachedTEX, CachedTypst})
    ct.ptr[] = load_pdf(ct.pdf)
    return ct.ptr[]
end

Base.convert(::Type{CachedPDF}, ct::Union{CachedTEX, CachedTypst}) = CachedPDF(PDFDocument(String(deepcopy(ct.pdf)), ct.doc.page), ct.ptr, ct.dims, ct.surf, Ref{Tuple{Matrix{ARGB32}, Float64}}((Matrix{ARGB32}(undef, 0, 0), 0)))
Base.convert(::Type{PDFDocument}, ct::Union{CachedTEX, CachedTypst}) = PDFDocument(String(deepcopy(ct.pdf)), ct.doc.page)

function _show(io, ct, x, y)
    if isnothing(ct.doc)
        println(io, x, "(no document, $(ct.ptr), $(ct.dims))")
    elseif length(ct.doc.contents) > 1000
        println(io, x, "(", y, "(...), $(ct.ptr), $(ct.dims))")
    else
        println(io, x, "($(ct.doc), $(ct.ptr), $(ct.dims))")
    end
end

Base.show(io::IO, ct::CachedTEX) = _show(io, ct, "CachedTEX", "TEXDocument")
Base.show(io::IO, ct::CachedTypst) = _show(io, ct, "CachedTypst", "TypstDocument")

function implant_math(str)
    return TEXDocument(
        """\\(\\displaystyle $str\\)""", true;
        requires = "\\RequirePackage{luatex85}",
        preamble = """
        \\usepackage{amsmath, amsfonts, xcolor}
        \\pagestyle{empty}
        \\nopagecolor
        """,
        class = "standalone",
        classoptions = "preview, tightpage, 12pt",
    )
end

function implant_text(str)
    return TEXDocument(
        String(str), true;
        requires = "\\RequirePackage{luatex85}",
        preamble = """
        \\usepackage{amsmath, amsfonts, xcolor}
        \\pagestyle{empty}
        \\nopagecolor
        """,
        class = "standalone",
        classoptions = "preview, tightpage, 12pt"
    )
end


# Define bounding box methods for CachedTex

"""
Calculate an approximation of a tight rectangle around a 2D rectangle rotated by `angle` radians.
This is not perfect but works well enough. Check an A vs X to see the difference.
"""
function rotatedrect(rect::Rect{2, T}, angle)::Rect{2, T} where T
    ox, oy = rect.origin
    wx, wy = rect.widths
    points = Makie.Mat{2, 4, T}(
        ox, oy,
        ox, oy+wy,
        ox+wx, oy,
        ox+wx, oy+wy
    )
    mrot = Makie.Mat{2, 2, T}(
        cos(angle), -sin(angle),
        sin(angle), cos(angle)
    )
    rotated = mrot * points

    rmins = minimum(rotated; dims=2)
    rmaxs = maximum(rotated; dims=2)

    return Rect2(rmins..., (rmaxs .- rmins)...)
end

function Makie.boundingbox(ct::Union{CachedTEX, CachedTypst}, position, rotation, scale, align)
    origin = offset_from_align(align, ct.dims)
    box = Rect2f(Point2f(origin), Vec2f(ct.dims) * scale)
    rect = rotatedrect(box, rotation)
    new_origin = Point3f(rect.origin..., 0)
    new_widths = Vec3f(rect.widths..., 0)
    return Rect3f(new_origin + position, new_widths)
end

# this method copied from Makie.jl
function Makie.boundingbox(cts::AbstractVector{<:Union{CachedTEX, CachedTypst}}, positions, rotations, scale, align)
    isempty(cts) && (return Rect3f((0, 0, 0), (0, 0, 0)))

    bb = Rect3f()
    broadcast_foreach(cts, positions, rotations, scale, align) do ct, pos, rot, scl, aln
        if !Makie.isfinite_rect(bb)
            bb = Makie.boundingbox(ct, pos, rot, scl, aln)
        else
            bb = Makie.union(bb, Makie.boundingbox(ct, pos, rot, scl, aln))
        end
    end
    !Makie.isfinite_rect(bb) && error("Invalid `TeX` boundingbox")
    return bb
end
