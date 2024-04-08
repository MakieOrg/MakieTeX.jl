# Rendering methods

This folder contains rendering methods for all the file formats supported by MakieTex, that is, `LaTeX`, `PDF`, and `SVG`.  Support for Typst may be coming in the future!

We define the concept of "rendering" here as the consumption and conversion of a generated file, either TeX, PDF or SVG, into something which can be directly plotted.  This means loading it in, saving it in a vector form, and subsequently also rasterizing it to a desired scale.

## Rendering API

The rendering pipeline ingests `AbstractDocuments` and turns them into `AbstractCachedDocument`s.

These can be retrieved by two functions:
```@docs
draw_to_cairo_surface
rasterize
```

```@docs
AbstractCachedDocument
```