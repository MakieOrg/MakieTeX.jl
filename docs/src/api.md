# API documentation

## Constants

```@docs
RENDER_DENSITY
RENDER_EXTRASAFE
CURRENT_TEX_ENGINE
_PDFCROP_DEFAULT_MARGINS
```

## Interfaces

### `AbstractDocument`

```@docs
AbstractDocument
getdoc
mimetype
Cached
```

### `AbstractCachedDocument`

```@docs
AbstractCachedDocument
rasterize
draw_to_cairo_surface
update_handle!
```

## Document types

### Raw document types
```@docs
SVGDocument
PDFDocument
EPSDocument
TEXDocument
```
### Cached document types
```@docs
CachedTEX
CachedPDF
CachedSVG
CachedEPS
```

TODO: add documentation about the LaTeX (`compile_latex`), PDF and SVG handling utils here, in case they are of use to anyone.

## All other methods and functions

```@autodocs
Modules = [MakieTeX]
```

