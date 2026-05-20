# Vector markers

[`MakieTeX.PDF`](@ref) and [`MakieTeX.SVG`](@ref) wrap a vector asset for use as a scatter `marker`. The asset's own styling (fills, strokes, gradients) is preserved as-is — there's no Makie-controlled color override.

- **CairoMakie** renders the asset vector-natively (Poppler for PDF, librsvg for SVG) — no raster intermediate, hairlines stay crisp at any zoom.
- **GLMakie / WGLMakie** rasterize the asset to an ARGB32 image at GPU-upload time.

Constructors accept either a file path or a `Vector{UInt8}` of the file bytes:

```julia
MakieTeX.PDF("path/to/asset.pdf"; page = 1)
MakieTeX.PDF(read("path/to/asset.pdf"); page = 1)

MakieTeX.SVG("path/to/asset.svg")
MakieTeX.SVG(read("path/to/asset.svg"))
```

`markersize` follows the same convention as `Char` / `BezierPath` markers: a scalar sets the **longer** dimension, and the shorter dimension scales proportionally so the asset's aspect ratio is preserved.

## SVG

```@example markers
using CairoMakie, MakieTeX

dots = MakieTeX.SVG(joinpath(@__DIR__, "assets/julia_dots.svg"))

fig = Figure()
ax = Axis(fig[1, 1]; limits = (0, 11, 0, 1))
scatter!(ax, 1:10, rand(10); marker = dots, markersize = 40)
fig
```

For a single-path SVG you want to recolor, use Makie's built-in [`BezierPath`](https://docs.makie.org/stable/reference/plots/scatter#BezierPath-markers) SVG path instead — that goes through Makie's normal `color` / `strokecolor` plumbing.

A vector of `MakieTeX.SVG`s works the same way as any other per-point marker — each scatter point can use a different asset:

```@example markers
python = MakieTeX.SVG(joinpath(@__DIR__, "assets/python.svg"))
matlab = MakieTeX.SVG(joinpath(@__DIR__, "assets/matlab.svg"))

fig = Figure()
ax = Axis(fig[1, 1]; limits = (0, 7, 0, 1))
markers = [dots, python, matlab, dots, python, matlab]
scatter!(ax, 1:6, [0.5, 0.7, 0.4, 0.6, 0.3, 0.8]; marker = markers, markersize = 50)
fig
```

## PDF

```@example markers
dots_pdf = MakieTeX.PDF(joinpath(@__DIR__, "assets/julia_dots.pdf"))

fig = Figure()
ax = Axis(fig[1, 1]; limits = (0, 11, 0, 1))
scatter!(ax, 1:10, rand(10); marker = dots_pdf, markersize = 40)
fig
```

Multi-page PDFs can pick a page via the `page` keyword (1-based):

```julia
MakieTeX.PDF("multipage.pdf"; page = 3)
```
