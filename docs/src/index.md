# MakieTeX.jl

MakieTeX is a package that allows users to plot vector images - PDF, SVG, and TeX (which compiles to PDF) directly in Makie.  It exposes two approaches: the `teximg` recipe which plots any LaTeX-like object, and the `CachedDocument` API which allows users to plot documents directly as `scatter` markers.



```@index
```
## Principle of operation

### Rendering

Rendering can occur either to a bitmap (for GL backends) or to a Cairo surface (for CairoMakie).  Both of these have APIs ([`rasterize`](@ref) and [`draw_to_cairo_surface`](@ref)).

Each rendering format has its own complexities, so the rendering pipelines are usually separate.  SVG uses librsvg, PDF and EPS use Poppler directly, and TeX uses the available local TeX render (if not, `tectonic` is bundled with MakieTeX) to render to a PDF, which then follows the Poppler pipeline. 

A hypothetical future Typst backend would likely also be a Typst -> PDF -> Poppler pipeline.  [Typst_jll](https://github.com/JuliaBinaryWrappers/Typst_jll.jl) already exists, so it would be fairly easy to bundle.

### Makie

When rendering to Makie, MakieTeX rasterizes the document to a bitmap by default via the Makie attribute conversion pipeline (specifically `Makie.to_spritemarker`), and then Makie treats it like a general image scatter marker.

**HOWEVER**, when rendering with CairoMakie, there is a function hook to get the correct marker for *Cairo* specifically, ignoring the default Makie conversion pipeline.  This is `CairoMakie.cairo_scatter_marker`, and we overload it in `MakieTeX.MakieTeXCairoMakieExt` to get the correct marker.  This also allows us to apply styling to SVG elements, but again **ONLY IN CAIROMAKIE**!  This is a bit of an incompatibility and a breaking of the implicit promise from Makie that rendering should be the same across backends, but the tradeoff is (to me, at least) worth it.