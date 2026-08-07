# PDF & SVG

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

A vector of `MakieTeX.SVG`s works the same way as any other per-point marker — each scatter point can use a different asset. Combined with `marker_offset` (in pixels), this is enough to drop a logo onto the tip of every bar in a horizontal barplot:

```@example markers
python = MakieTeX.SVG(joinpath(@__DIR__, "assets/python.svg"))
matlab = MakieTeX.SVG(joinpath(@__DIR__, "assets/matlab.svg"))

languages = ["Julia", "Python", "MATLAB"]
ages      = [14, 35, 42]            # years since first release, 2026
logos     = [dots, python, matlab]

fig = Figure(size = (640, 240))
ax = Axis(fig[1, 1];
    title  = "Age of programming languages in 2026",
    xlabel = "years since first release",
    yticks = (1:length(languages), languages),
    limits = (0, 52, 0.4, length(languages) + 0.6),
    xgridvisible = false, ygridvisible = false,
    yticksvisible = false,
)
hidespines!(ax, :t, :r)

barplot!(ax, 1:length(ages), ages;
    direction = :x, color = (:steelblue, 0.4), strokewidth = 0,
    bar_labels = ["$(a) years" for a in ages], label_offset = 8)

scatter!(ax, ages, 1:length(ages); marker = logos, markersize = 28,
    marker_offset = Vec2f(-20, 0))
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
