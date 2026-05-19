```@raw html
---
layout: home

hero:
  name: "MakieTeX.jl"
  text: ""
  tagline: Real LaTeX and Typst in Makie
  actions:
    - theme: brand
      text: LaTeX
      link: /latex
    - theme: alt
      text: Typst
      link: /typst
    - theme: alt
      text: Vector markers
      link: /markers
    - theme: alt
      text: GitHub
      link: https://github.com/MakieOrg/MakieTeX.jl

features:
  - title: Real LaTeX engine
    details: Route `LaTeXString` content through tectonic / pdflatex / lualatex instead of MathTeXEngine's glyph approximation — use any LaTeX package, real math typography.
    link: /latex
  - title: Typst compiler
    details: Same idea for `typst"…"` strings. Fast, modern, looks great out of the box.
    link: /typst
  - title: PDF & SVG markers
    details: Drop a vector asset onto a scatter plot. CairoMakie renders vector-native; GLMakie / WGLMakie rasterize at GPU upload.
    link: /markers
---
```

# MakieTeX.jl

MakieTeX plugs into [Makie](https://docs.makie.org/)'s `text` recipe via a `text_handler` attribute. Drop in a real engine (LaTeX or Typst) for individual text elements — titles, axis labels, annotations — or route every string through the engine so fonts match across the whole figure.

It also adds [`MakieTeX.PDF`](@ref) and [`MakieTeX.SVG`](@ref) types for using vector assets as scatter markers.

## Install

```julia
import Pkg
Pkg.add("MakieTeX")
```

The engines load via package extensions:

- **LaTeX** — `import tectonic_jll` (bundled, easiest) or have `latexmk` on `PATH` (uses your local TeX install / packages).
- **Typst** — `import Typstry` (bundles the Typst compiler).

## Minimal example

```@example index
using CairoMakie, MakieTeX

set_theme!(text_handler = MakieTeX.LaTeX(render_strings = true))

fig = Figure()
Axis(fig[1, 1];
    title = L"\int_0^\pi \sin(x)^2\, dx = \tfrac{\pi}{2}",
    xlabel = L"x", ylabel = L"\sin^2(x)",
)
lines!(0:0.01:π, x -> sin(x)^2)
set_theme!() # hide
fig
```
