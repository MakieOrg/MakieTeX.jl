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

### Makie.jl function definitions
The backend-specific functions and rasterizers are kept in the backends' extensions.

These functions are generic to the Makie API.
=#
# Pass the cached document through untouched so backends with native vector
# dispatch (CairoMakie's `draw_marker(::CachedPDF, …)`) get it, and GPU
# backends can rasterize via `rasterize_marker_for_gpu`.
Makie.to_spritemarker(x::AbstractCachedDocument) = x
Makie.marker_to_sdf_shape(::AbstractCachedDocument) = Makie.RECTANGLE
Makie.el32convert(x::AbstractCachedDocument) = rasterize(x, MakieTeX.RENDER_DENSITY[])

Makie.to_spritemarker(x::AbstractDocument) = Cached(x)

#=
## Concrete type definitions

Now, we define the structs which hold the documents and their cached versions.

### Raw documents
=#

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


# Bounding box methods

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

