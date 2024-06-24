```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "MakieTeX"
  text: ""
  tagline: Plotting vector images in Makie
  actions:
    - theme: brand
      text: Introduction
      link: /index
    - theme: alt
      text: View on Github
      link: https://github.com/JuliaPlots/MakieTeX.jl
    - theme: alt
      text: Available formats
      link: /formats

features:
  - icon: <img width="64" height="64" src="https://rawcdn.githack.com/JuliaLang/julia-logo-graphics/f3a09eb033b653970c5b8412e7755e3c7d78db9e/images/juliadots.iconset/icon_512x512.png" alt="Julia code"/>
    title: TeX, PDF, SVG
    details: Renders vector formats like TeX, PDF and SVG with no external dependencies
    link: /formats
---


<p style="margin-bottom:2cm"></p>

<div class="vp-doc" style="width:80%; margin:auto">

```

# MakieTeX.jl

MakieTeX is a package that allows users to plot vector images - PDF, SVG, and TeX (which compiles to PDF) directly in Makie.  It exposes two approaches: the `teximg` recipe which plots any LaTeX-like object, and the `CachedDocument` API which allows users to plot documents directly as `scatter` markers.

To see a list of all exported functions, types, and macros, see the [API](@ref api) page.

```@example LTeX
using MakieTeX, CairoMakie

teximg(raw"""
\begin{align*}
\frac{1}{2} \times \frac{1}{2} = \frac{1}{4}
\end{align*}
""")
```


## Principle of operation

### Rendering

Rendering can occur either to a bitmap (for GL backends) or to a Cairo surface (for CairoMakie).  Both of these have APIs ([`rasterize`](@ref) and [`draw_to_cairo_surface`](@ref)).

Each rendering format has its own complexities, so the rendering pipelines are usually separate.  SVG uses librsvg while PDF and EPS use Poppler directly. TeX uses the available local TeX renderer (if not, `tectonic` is bundled with MakieTeX) and Typst uses Typst_jll.jl to render to a PDF, which then each follow the Poppler pipeline.

### Makie

When rendering to Makie, MakieTeX rasterizes the document to a bitmap by default via the Makie attribute conversion pipeline (specifically `Makie.to_spritemarker`), and then Makie treats it like a general image scatter marker.

**HOWEVER**, when rendering with CairoMakie, there is a function hook to get the correct marker for *Cairo* specifically, ignoring the default Makie conversion pipeline.  This is `CairoMakie.cairo_scatter_marker`, and we overload it in `MakieTeX.MakieTeXCairoMakieExt` to get the correct marker.  This also allows us to apply styling to SVG elements, but again **ONLY IN CAIROMAKIE**!  This is a bit of an incompatibility and a breaking of the implicit promise from Makie that rendering should be the same across backends, but the tradeoff is (to me, at least) worth it.

```@raw html
</div>
```
