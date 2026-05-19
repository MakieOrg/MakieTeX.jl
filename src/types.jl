"""
    abstract type AbstractDocument

Supertype for vector asset markers (`PDF`, `SVG`). Holds the document
bytes, a reference-counted library handle (Poppler / librsvg), and the
asset's intrinsic size. Used directly as a scatter `marker`; CairoMakie
renders it vector-natively, GPU backends rasterize to ARGB32 at upload.
"""
abstract type AbstractDocument end

# Mutable carrier so a finalizer can unref the underlying GObject.
# Poppler documents and librsvg handles are both GObjects, so they share
# `g_object_unref` from libgobject for cleanup.
mutable struct GObjectHandle
    ptr::Ptr{Cvoid}
    function GObjectHandle(ptr::Ptr{Cvoid})
        h = new(ptr)
        finalizer(h) do x
            if x.ptr != C_NULL
                ccall((:g_object_unref, Glib_jll.libgobject), Cvoid, (Ptr{Cvoid},), x.ptr)
                x.ptr = C_NULL
            end
        end
        return h
    end
end

"""
    PDF(path::AbstractString; page = 0)
    PDF(bytes::AbstractVector{UInt8}; page = 0)

A PDF asset usable as a scatter `marker`. The bytes are parsed by Poppler
at construction; `page` selects a zero-based page index. Renders
vector-native on CairoMakie; GLMakie / WGLMakie rasterize at GPU upload
via `Makie.rasterize_marker_for_gpu`.
"""
struct PDF <: AbstractDocument
    bytes::Vector{UInt8}
    page::Int
    handle::GObjectHandle
    dims::Tuple{Float64, Float64}
end

PDF(path::AbstractString; page::Integer = 0) = PDF(read(path); page)
function PDF(bytes::AbstractVector{UInt8}; page::Integer = 0)
    bytes_vec = collect(bytes)
    ptr = load_pdf(bytes_vec)
    page_idx = Int(page)
    dims = pdf_get_page_size(ptr, page_idx)
    return PDF(bytes_vec, page_idx, GObjectHandle(ptr), dims)
end

"""
    SVG(path::AbstractString)
    SVG(bytes::AbstractVector{UInt8})

An SVG asset usable as a scatter `marker`. The SVG's own styling
(fill / stroke / gradients / embedded images) is preserved as-is — there
is no Makie-controlled color override. For single-path SVGs that you want
to recolor, use Makie's built-in `BezierPath`-based SVG marker conversion
instead.
"""
struct SVG <: AbstractDocument
    bytes::Vector{UInt8}
    handle::GObjectHandle
    dims::Tuple{Float64, Float64}
end

SVG(path::AbstractString) = SVG(read(path))
function SVG(bytes::AbstractVector{UInt8})
    bytes_vec = collect(bytes)
    ptr = load_svg(bytes_vec)
    dims = svg_get_size(ptr)
    return SVG(bytes_vec, GObjectHandle(ptr), dims)
end

Base.size(doc::AbstractDocument) = doc.dims

# Marker hooks. AbstractDocument passes straight through Makie's marker
# pipeline — CairoMakie dispatches `draw_marker` on the concrete type, GPU
# backends call `rasterize_marker_for_gpu` to get a Matrix{ARGB32} at
# upload time.
Makie.to_spritemarker(x::AbstractDocument) = x
Makie.marker_to_sdf_shape(::AbstractDocument) = Makie.RECTANGLE
