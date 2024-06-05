# API documentation

## Constants

```@docs
MakieTeX.RENDER_DENSITY
MakieTeX.RENDER_EXTRASAFE
MakieTeX.CURRENT_TEX_ENGINE
MakieTeX._PDFCROP_DEFAULT_MARGINS
```

## Interfaces

### `AbstractDocument`

```@docs
MakieTeX.AbstractDocument
MakieTeX.getdoc
MakieTeX.mimetype
MakieTeX.Cached
```

### `AbstractCachedDocument`

```@docs
MakieTeX.AbstractCachedDocument
MakieTeX.rasterize
MakieTeX.draw_to_cairo_surface
MakieTeX.update_handle!
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

