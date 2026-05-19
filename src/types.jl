"""
    abstract type AbstractDocument

Supertype for vector asset markers (`PDF`, `SVG`). Carries the document
bytes plus lazily-populated library handles and dimensions. Used directly
as a scatter `marker`; CairoMakie renders it vector-natively, GPU backends
rasterize to ARGB32 at upload time.
"""
abstract type AbstractDocument end

"""
    PDF(path::AbstractString; page = 0)
    PDF(bytes::AbstractVector{UInt8}; page = 0)

A PDF asset usable as a scatter `marker`. Renders vector-native on
CairoMakie (no raster intermediate); GLMakie / WGLMakie rasterize at GPU
upload via `Makie.rasterize_marker_for_gpu`.

`page` is zero-based; defaults to the first page.
"""
struct PDF <: AbstractDocument
    bytes::Vector{UInt8}
    page::Int
    handle::Ref{Ptr{Cvoid}}
    dims::Ref{Tuple{Float64, Float64}}
end

PDF(path::AbstractString; page::Integer = 0) = PDF(read(path); page)
function PDF(bytes::AbstractVector{UInt8}; page::Integer = 0)
    return PDF(
        collect(bytes), Int(page),
        Ref{Ptr{Cvoid}}(C_NULL),
        Ref{Tuple{Float64, Float64}}((0.0, 0.0)),
    )
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
    handle::Ref{Ptr{Cvoid}}
    dims::Ref{Tuple{Float64, Float64}}
end

SVG(path::AbstractString) = SVG(read(path))
function SVG(bytes::AbstractVector{UInt8})
    return SVG(
        collect(bytes),
        Ref{Ptr{Cvoid}}(C_NULL),
        Ref{Tuple{Float64, Float64}}((0.0, 0.0)),
    )
end

# Populate the lazy handle on first use. Library handles can outlive
# their Julia owner; on a stale-handle error a backend can re-call this.
function ensure_loaded!(doc::AbstractDocument) end

function dims(doc::AbstractDocument)::Tuple{Float64, Float64}
    ensure_loaded!(doc)
    return doc.dims[]
end

Base.size(doc::AbstractDocument) = dims(doc)

# Marker hooks. AbstractDocument passes straight through Makie's marker
# pipeline — CairoMakie dispatches `draw_marker` on the concrete type, GPU
# backends call `rasterize_marker_for_gpu` to get a Matrix{ARGB32} at
# upload time.
Makie.to_spritemarker(x::AbstractDocument) = x
Makie.marker_to_sdf_shape(::AbstractDocument) = Makie.RECTANGLE
