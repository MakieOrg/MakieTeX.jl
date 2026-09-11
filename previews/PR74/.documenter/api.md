
# API documentation {#api}

## Constants {#Constants}
<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.RENDER_DENSITY' href='#MakieTeX.RENDER_DENSITY'><span class="jlbinding">MakieTeX.RENDER_DENSITY</span></a> <Badge type="info" class="jlObjectType jlConstant" text="Constant" /></summary>



Default density when rendering images


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/MakieTeX.jl#L26" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.RENDER_EXTRASAFE' href='#MakieTeX.RENDER_EXTRASAFE'><span class="jlbinding">MakieTeX.RENDER_EXTRASAFE</span></a> <Badge type="info" class="jlObjectType jlConstant" text="Constant" /></summary>



Render with Poppler pipeline (true) or Cairo pipeline (false)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/MakieTeX.jl#L20" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.CURRENT_TEX_ENGINE' href='#MakieTeX.CURRENT_TEX_ENGINE'><span class="jlbinding">MakieTeX.CURRENT_TEX_ENGINE</span></a> <Badge type="info" class="jlObjectType jlConstant" text="Constant" /></summary>



The current `TeX` engine which MakieTeX uses.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/MakieTeX.jl#L22" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX._PDFCROP_DEFAULT_MARGINS' href='#MakieTeX._PDFCROP_DEFAULT_MARGINS'><span class="jlbinding">MakieTeX._PDFCROP_DEFAULT_MARGINS</span></a> <Badge type="info" class="jlObjectType jlConstant" text="Constant" /></summary>



Default margins for `pdfcrop`.  Private, try not to touch!


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/MakieTeX.jl#L24" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Interfaces {#Interfaces}

### `AbstractDocument` {#AbstractDocument}
<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.AbstractDocument' href='#MakieTeX.AbstractDocument'><span class="jlbinding">MakieTeX.AbstractDocument</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
abstract type AbstractDocument
```


An `AbstractDocument` must contain a document as a String or Vector{UInt8} of the full contents  of whichever file it is using.  It may contain additional fields - for example, `PDFDocument`s  contain a page number to indicate which page to display, in the case where a PDF has multiple pages.

`AbstractDocument`s must implement the following functions:
- `getdoc(doc::AbstractDocument)::Union{Vector{UInt8}, String}`
  
- `mimetype(doc::AbstractDocument)::Base.MIME`
  
- `Cached(doc::AbstractDocument)::AbstractCachedDocument`
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L19-L30" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.getdoc' href='#MakieTeX.getdoc'><span class="jlbinding">MakieTeX.getdoc</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
getdoc(doc::AbstractDocument)::Union{Vector{UInt8}, String}
```


Return the document data (contents of the file) as a `Vector{UInt8}` or `String`. This must be the full file, i.e., if it was saved, the file should be immediately openable.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L33-L38" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.mimetype' href='#MakieTeX.mimetype'><span class="jlbinding">MakieTeX.mimetype</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
mimetype(::Type{<: AbstractDocument})::Base.MIME
mimetype(::AbstractDocument)::Base.MIME
```


Return the MIME type of the document.  For example, `mimetype(::SVGDocument) == MIME("image/svg+xml")`.

::: tip Note

This is generally defined for the type, and there is a  generic overload when passing a constructed object.

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L40-L49" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.Cached' href='#MakieTeX.Cached'><span class="jlbinding">MakieTeX.Cached</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
Cached(doc::AbstractDocument)::AbstractCachedDocument
```


Generic interface to cache a document and return it.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L51-L55" target="_blank" rel="noreferrer">source</a></Badge>

</details>


### `AbstractCachedDocument` {#AbstractCachedDocument}
<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.AbstractCachedDocument' href='#MakieTeX.AbstractCachedDocument'><span class="jlbinding">MakieTeX.AbstractCachedDocument</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
abstract type AbstractCachedDocument
```


Cached documents are &quot;loaded&quot; versions of AbstractDocuments, and store a pointer/reference to the  loaded version of the document (a Poppler handle for PDFs, or Rsvg handle for SVGs).  

They also contain a Cairo surface to which the document has been rendered, as well as a cache of a  rasterized PNG and its scale for performance reasons.  See the documentation of [`rasterize`](/api#MakieTeX.rasterize) for more.

`AbstractCachedDocument`s must implement the [`AbstractDocument`](/api#AbstractDocument) API, as well as the following:
- `rasterize(doc::AbstractCachedDocument, [scale::Real = 1])::Matrix{ARGB32}`
  
- `draw_to_cairo_surface(doc::AbstractCachedDocument, surf::CairoSurface)`
  
- `update_handle!(doc::AbstractCachedDocument)::<some_handle_type>`
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L58-L72" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.rasterize' href='#MakieTeX.rasterize'><span class="jlbinding">MakieTeX.rasterize</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
rasterize(doc::AbstractCachedDocument, scale::Real = 1)
```


Render a `CachedDocument` to an image at a given scale.  This is a convenience function which calls the appropriate rendering function for the document type.  Returns an image as a `Matrix{ARGB32}`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L76-L81" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.draw_to_cairo_surface' href='#MakieTeX.draw_to_cairo_surface'><span class="jlbinding">MakieTeX.draw_to_cairo_surface</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
draw_to_cairo_surface(doc::AbstractCachedDocument, surf::CairoSurface)
```


Render a `CachedDocument` to a Cairo surface.  This is a convenience function which calls the appropriate rendering function for the document type.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L84-L89" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.update_handle!' href='#MakieTeX.update_handle!'><span class="jlbinding">MakieTeX.update_handle!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
update_handle!(doc::AbstractCachedDocument)
```


Update the internal handle/pointer to the loaded document in a `CachedDocument`, and returns it.

This function is used to refresh the handle/pointer to the loaded document in case it has been garbage collected or invalidated. It should return the updated handle/pointer.

For example, in `CachedPDF`, this function would reload the PDF document using the `doc.doc` field and update the `ptr` field with the new Poppler handle, **if it is found to be invalid**.

Note that this function needs to be implemented for each concrete subtype of `AbstractCachedDocument`, as the handle/pointer type and the method to load/update it will be different for different document types (e.g., PDF, SVG, etc.).


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L92-L106" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Document types {#Document-types}

### Raw document types {#Raw-document-types}
<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.SVGDocument' href='#MakieTeX.SVGDocument'><span class="jlbinding">MakieTeX.SVGDocument</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
SVGDocument(svg::AbstractString)
```


A document type which stores an SVG string.

Is converted to [`CachedSVG`](/api#MakieTeX.CachedSVG) for use in plotting.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L154-L160" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.PDFDocument' href='#MakieTeX.PDFDocument'><span class="jlbinding">MakieTeX.PDFDocument</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
PDFDocument(pdf::AbstractString, [page = 0])
```


A document type which holds a raw PDF as a string.

Is converted to [`CachedPDF`](/api#MakieTeX.CachedPDF) for use in plotting.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L168-L174" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.EPSDocument' href='#MakieTeX.EPSDocument'><span class="jlbinding">MakieTeX.EPSDocument</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
EPSDocument(eps::AbstractString, [page = 0])
```


A document type which holds an EPS string.

Is converted to [`CachedPDF`](/api#MakieTeX.CachedPDF) for use in plotting.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L185-L191" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.TEXDocument' href='#MakieTeX.TEXDocument'><span class="jlbinding">MakieTeX.TEXDocument</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
TEXDocument(contents::AbstractString, add_defaults::Bool; requires, preamble, class, classoptions)
```


This constructor function creates a `struct` of type `TEXDocument` which can be passed to `teximg`. All arguments are to be passed as strings.

If `add_defaults` is `false`, then we will _not_ automatically add document structure. Note that in this case, keyword arguments will be disregarded and `contents` must be a complete LaTeX document.

Available keyword arguments are:
- `requires`: code which comes before `documentclass` in the preamble.  Default: `raw"\RequirePackage{luatex85}"`.
  
- `class`: the document class.  Default (and what you should use): `"standalone"`.
  
- `classoptions`: the options you should pass to the class, i.e., `\documentclass[$classoptions]{$class}`.  Default: `"preview, tightpage, 12pt"`.
  
- `preamble`: arbitrary code for the preamble (between `\documentclass` and `\begin{document}`).  Default: `raw"\usepackage{amsmath, xcolor} \pagestyle{empty}"`.
  

See also [`CachedTEX`](/api#MakieTeX.CachedTEX), [`compile_latex`](/api#MakieTeX.compile_latex-Tuple{AbstractString}), etc.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L213-L230" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.TypstDocument' href='#MakieTeX.TypstDocument'><span class="jlbinding">MakieTeX.TypstDocument</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
TypstDocument(contents::AbstractString, add_defaults::Bool; preamble)
```


This constructor function creates a `struct` of type `TypstDocument`. All arguments are to be passed as strings.

If `add_defaults` is `false`, then we will _not_ automatically add document structure. Note that in this case, keyword arguments will be disregarded and `contents` must be a complete Typst document.

Available keyword arguments are:
- `preamble`: arbitrary code inserted prior to the `contents`.  Default: `""`.
  

See also [`CachedTypst`](/api#MakieTeX.CachedTypst), [`compile_typst`](/api#MakieTeX.compile_typst-Tuple{AbstractString}), etc.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L289-L303" target="_blank" rel="noreferrer">source</a></Badge>

</details>


### Cached document types {#Cached-document-types}
<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.CachedTEX' href='#MakieTeX.CachedTEX'><span class="jlbinding">MakieTeX.CachedTEX</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
CachedTEX(doc::TEXDocument; kwargs...)
```


Compile a `TEXDocument`, compile it and return the cached TeX object.

A `CachedTEX` struct stores the document and its compiled form, as well as some pointers to in-program versions of it.  It also stores the page dimensions.

In `kwargs`, one can pass anything which goes to the internal function `compile_latex`. These are primarily:
- `engine =`lualatex`/`xelatex`/...`: the LaTeX engine to use when rendering
  
- `options=`-file-line-error``: the options to pass to`latexmk`.
  

The constructor stores the following fields:
- `doc`
  
- `pdf`
  
- `ptr`
  
- `surf`
  
- `dims`
  

::: tip Note

This is a `mutable struct` because the pointer to the Poppler handle can change. TODO: make this an immutable struct with a Ref to the handle??  OR maybe even the surface itself...

:::

::: tip Note

It is also possible to manually construct a `CachedTEX` with `nothing` in the `doc` field,  if you just want to insert a pre-rendered PDF into your figure.

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L436-L459" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.CachedTypst' href='#MakieTeX.CachedTypst'><span class="jlbinding">MakieTeX.CachedTypst</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
CachedTypst(doc::TypstDocument)
```


Compile a `TypstDocument`, compile it and return the cached Typst object.

A `CachedTypst` struct stores the document and its compiled form, as well as some pointers to in-program versions of it.  It also stores the page dimensions.

The constructor stores the following fields:
- `doc`
  
- `pdf`
  
- `ptr`
  
- `surf`
  
- `dims`
  

::: tip Note

This is a `mutable struct` because the pointer to the Poppler handle can change. TODO: make this an immutable struct with a Ref to the handle??  OR maybe even the surface itself...

:::

::: tip Note

It is also possible to manually construct a `CachedTypst` with `nothing` in the `doc` field,  if you just want to insert a pre-rendered PDF into your figure.

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L495-L513" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.CachedPDF' href='#MakieTeX.CachedPDF'><span class="jlbinding">MakieTeX.CachedPDF</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
CachedPDF(pdf::PDFDocument)
```


Holds a PDF document along with a Poppler handle and a Cairo surface to which it has already  been rendered.

**Usage**

```julia
CachedPDF(read("path/to/pdf.pdf"), [page = 0])
CachedPDF(read("path/to/pdf.pdf", String), [page = 0])
CachedPDF(PDFDocument(...), [page = 0])
```


**Fields**
- `doc`: A reference to the `PDFDocument` which is cached here.
  
- `ptr`: A pointer to the Poppler handle of the PDF.  May be randomly GC&#39;ed by Poppler.
  
- `dims`: The dimensions of the PDF page in points, for ease of access.
  
- `surf`: A Cairo surface to which Poppler has drawn the PDF.  Permanent and cached.
  
- `image_cache`: A cache for a (rendered_image, scale_factor) pair.  This is used to avoid re-rendering the PDF.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L340-L358" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.CachedSVG' href='#MakieTeX.CachedSVG'><span class="jlbinding">MakieTeX.CachedSVG</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
CachedSVG(svg::SVGDocument)
```


Holds an SVG document along with an Rsvg handle and a Cairo surface to which it has already been rendered.

**Usage**

```julia
CachedSVG(read("path/to/svg.svg"))
CachedSVG(read("path/to/svg.svg", String))
CachedSVG(SVGDocument(...))
```


**Fields**
- `doc`: The original `SVGDocument` which is cached here, i.e., the text of that SVG.
  
- `handle`: A pointer to the Rsvg handle of the SVG.  May be randomly GC&#39;ed by Rsvg, so is stored as a `Ref` in case it has to be refreshed.
  
- `dims`: The dimensions of the SVG in points, for ease of access.
  
- `surf`: A Cairo surface to which Rsvg has drawn the SVG.  Permanent and cached.
  
- `image_cache`: A cache for a (rendered_image, scale_factor) pair.  This is used to avoid re-rendering the PDF.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L380-L397" target="_blank" rel="noreferrer">source</a></Badge>

</details>


TODO: add documentation about the LaTeX (`compile_latex`), PDF and SVG handling utils here, in case they are of use to anyone.

## All other methods and functions {#All-other-methods-and-functions}
<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.CachedTEX-Tuple{TEXDocument}' href='#MakieTeX.CachedTEX-Tuple{TEXDocument}'><span class="jlbinding">MakieTeX.CachedTEX</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
CachedTEX(doc::TEXDocument; kwargs...)
```


Compile a `TEXDocument`, compile it and return the cached TeX object.

A `CachedTEX` struct stores the document and its compiled form, as well as some pointers to in-program versions of it.  It also stores the page dimensions.

In `kwargs`, one can pass anything which goes to the internal function `compile_latex`. These are primarily:
- `engine =`lualatex`/`xelatex`/...`: the LaTeX engine to use when rendering
  
- `options=`-file-line-error``: the options to pass to`latexmk`.
  

The constructor stores the following fields:
- `doc`
  
- `pdf`
  
- `ptr`
  
- `surf`
  
- `dims`
  

::: tip Note

This is a `mutable struct` because the pointer to the Poppler handle can change. TODO: make this an immutable struct with a Ref to the handle??  OR maybe even the surface itself...

:::

::: tip Note

It is also possible to manually construct a `CachedTEX` with `nothing` in the `doc` field,  if you just want to insert a pre-rendered PDF into your figure.

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L436-L459" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.CachedTypst-Tuple{TypstDocument}' href='#MakieTeX.CachedTypst-Tuple{TypstDocument}'><span class="jlbinding">MakieTeX.CachedTypst</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
CachedTypst(doc::TypstDocument)
```


Compile a `TypstDocument`, compile it and return the cached Typst object.

A `CachedTypst` struct stores the document and its compiled form, as well as some pointers to in-program versions of it.  It also stores the page dimensions.

The constructor stores the following fields:
- `doc`
  
- `pdf`
  
- `ptr`
  
- `surf`
  
- `dims`
  

::: tip Note

This is a `mutable struct` because the pointer to the Poppler handle can change. TODO: make this an immutable struct with a Ref to the handle??  OR maybe even the surface itself...

:::

::: tip Note

It is also possible to manually construct a `CachedTypst` with `nothing` in the `doc` field,  if you just want to insert a pre-rendered PDF into your figure.

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L495-L513" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.LTeX' href='#MakieTeX.LTeX'><span class="jlbinding">MakieTeX.LTeX</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



**`MakieTeX.LTeX <: Block`**

No docstring defined.

**Attributes**

(type `?MakieTeX.LTeX.x` in the REPL for more information about attribute `x`)

`alignmode`, `halign`, `height`, `padding`, `render_density`, `rotation`, `scale`, `tellheight`, `tellwidth`, `tex`, `valign`, `visible`, `width`


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/Makie.jl/blob/v0.24.10/src/makielayout/blocks.jl#L118-L129" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.TEXDocument-Tuple{AbstractString, Bool}' href='#MakieTeX.TEXDocument-Tuple{AbstractString, Bool}'><span class="jlbinding">MakieTeX.TEXDocument</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
TEXDocument(contents::AbstractString, add_defaults::Bool; requires, preamble, class, classoptions)
```


This constructor function creates a `struct` of type `TEXDocument` which can be passed to `teximg`. All arguments are to be passed as strings.

If `add_defaults` is `false`, then we will _not_ automatically add document structure. Note that in this case, keyword arguments will be disregarded and `contents` must be a complete LaTeX document.

Available keyword arguments are:
- `requires`: code which comes before `documentclass` in the preamble.  Default: `raw"\RequirePackage{luatex85}"`.
  
- `class`: the document class.  Default (and what you should use): `"standalone"`.
  
- `classoptions`: the options you should pass to the class, i.e., `\documentclass[$classoptions]{$class}`.  Default: `"preview, tightpage, 12pt"`.
  
- `preamble`: arbitrary code for the preamble (between `\documentclass` and `\begin{document}`).  Default: `raw"\usepackage{amsmath, xcolor} \pagestyle{empty}"`.
  

See also [`CachedTEX`](/api#MakieTeX.CachedTEX), [`compile_latex`](/api#MakieTeX.compile_latex-Tuple{AbstractString}), etc.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L213-L230" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.TeXImg' href='#MakieTeX.TeXImg'><span class="jlbinding">MakieTeX.TeXImg</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



`TeXImg` is the plot type associated with plotting function `teximg`. Check the docstring for `teximg` for further information.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/Makie.jl/blob/v0.24.10/src/recipes.jl#L541" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.TypstDocument-Tuple{AbstractString, Bool}' href='#MakieTeX.TypstDocument-Tuple{AbstractString, Bool}'><span class="jlbinding">MakieTeX.TypstDocument</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
TypstDocument(contents::AbstractString, add_defaults::Bool; preamble)
```


This constructor function creates a `struct` of type `TypstDocument`. All arguments are to be passed as strings.

If `add_defaults` is `false`, then we will _not_ automatically add document structure. Note that in this case, keyword arguments will be disregarded and `contents` must be a complete Typst document.

Available keyword arguments are:
- `preamble`: arbitrary code inserted prior to the `contents`.  Default: `""`.
  

See also [`CachedTypst`](/api#MakieTeX.CachedTypst), [`compile_typst`](/api#MakieTeX.compile_typst-Tuple{AbstractString}), etc.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L289-L303" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX._RsvgRectangle' href='#MakieTeX._RsvgRectangle'><span class="jlbinding">MakieTeX._RsvgRectangle</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



RsvgRectangle is a simple struct of:     height::Float64     width::Float64     x::Float64     y::Float64


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/svg.jl#L31-L37" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.__init__-Tuple{}' href='#MakieTeX.__init__-Tuple{}'><span class="jlbinding">MakieTeX.__init__</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Checks whether the default latex engine is correct


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/MakieTeX.jl#L69" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.compile_latex-Tuple{AbstractString}' href='#MakieTeX.compile_latex-Tuple{AbstractString}'><span class="jlbinding">MakieTeX.compile_latex</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
compile_latex(document::AbstractString; tex_engine = CURRENT_TEX_ENGINE[], options = `-file-line-error`)
```


Compile the given document as a String and return the resulting PDF (also as a String).


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/tex.jl#L10-L14" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.compile_typst-Tuple{AbstractString}' href='#MakieTeX.compile_typst-Tuple{AbstractString}'><span class="jlbinding">MakieTeX.compile_typst</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
compile_typst(document::AbstractString)
```


Compile the given document as a String and return the resulting PDF (also as a String).


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/typst.jl#L10-L14" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.crop_pdf-Tuple{String}' href='#MakieTeX.crop_pdf-Tuple{String}'><span class="jlbinding">MakieTeX.crop_pdf</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
crop_pdf(path; margin = (0, 0, 0, 0))
```


Crop a PDF file using Ghostscript.  This alters the crop box but does not actually remove elements.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/pdf_utils.jl#L140-L145" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.get_pdf_bbox-Tuple{String}' href='#MakieTeX.get_pdf_bbox-Tuple{String}'><span class="jlbinding">MakieTeX.get_pdf_bbox</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
get_pdf_bbox(path)
```


Get the bounding box of a PDF file using Ghostscript. Returns a tuple representing the (xmin, ymin, xmax, ymax) of the bounding box.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/pdf_utils.jl#L107-L112" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.handle_render_document-Tuple{Cairo.CairoContext, Rsvg.RsvgHandle, MakieTeX._RsvgRectangle}' href='#MakieTeX.handle_render_document-Tuple{Cairo.CairoContext, Rsvg.RsvgHandle, MakieTeX._RsvgRectangle}'><span class="jlbinding">MakieTeX.handle_render_document</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



handle_render_document(cr::CairoContext, handle::RsvgHandle, viewport::_RsvgRectangle)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/svg.jl#L45-L47" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.load_pdf-Tuple{String}' href='#MakieTeX.load_pdf-Tuple{String}'><span class="jlbinding">MakieTeX.load_pdf</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
load_pdf(pdf::String)::Ptr{Cvoid}
load_pdf(pdf::Vector{UInt8})::Ptr{Cvoid}
```


Loads a PDF file into a Poppler document handle.

Input may be either a String or a `Vector{UInt8}`, each representing the PDF file in memory.  

::: tip Warn

The String input does **NOT** represent a filename!

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/pdf.jl#L37-L47" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.page2img-Tuple{Union{CachedPDF, CachedTEX, CachedTypst}, Int64}' href='#MakieTeX.page2img-Tuple{Union{CachedPDF, CachedTEX, CachedTypst}, Int64}'><span class="jlbinding">MakieTeX.page2img</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
page2img(ct::Union{CachedTeX, CachedTypst}, page::Int; scale = 1, render_density = 1)
```


Renders the `page` of the given `CachedTeX` or `CachedTypst` object to an image, with the given `scale` and `render_density`.

This function reads the PDF using Poppler and renders it to a Cairo surface, which is then read as an image.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/pdf.jl#L88-L94" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.pdf_get_page_size-Tuple{Ptr{Nothing}, Int64}' href='#MakieTeX.pdf_get_page_size-Tuple{Ptr{Nothing}, Int64}'><span class="jlbinding">MakieTeX.pdf_get_page_size</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
pdf_get_page_size(document::Ptr{Cvoid}, page_number::Int)::Tuple{Float64, Float64}
```


`document` must be a Poppler document handle.  Returns a tuple of `width, height`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/pdf_utils.jl#L42-L46" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.pdf_num_pages-Tuple{Ptr{Nothing}}' href='#MakieTeX.pdf_num_pages-Tuple{Ptr{Nothing}}'><span class="jlbinding">MakieTeX.pdf_num_pages</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
pdf_num_pages(document::Ptr{Cvoid})::Int
```


`document` must be a Poppler document handle.  Returns the number of pages in the document.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/pdf_utils.jl#L28-L32" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.pdf_num_pages-Tuple{String}' href='#MakieTeX.pdf_num_pages-Tuple{String}'><span class="jlbinding">MakieTeX.pdf_num_pages</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
pdf_num_pages(filename::String)::Int
```


Returns the number of pages in a PDF file located at `filename`, using the Poppler executable.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/pdf_utils.jl#L9-L13" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.rotatedrect-Union{Tuple{T}, Tuple{GeometryBasics.HyperRectangle{2, T}, Any}} where T' href='#MakieTeX.rotatedrect-Union{Tuple{T}, Tuple{GeometryBasics.HyperRectangle{2, T}, Any}} where T'><span class="jlbinding">MakieTeX.rotatedrect</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Calculate an approximation of a tight rectangle around a 2D rectangle rotated by `angle` radians. This is not perfect but works well enough. Check an A vs X to see the difference.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L609-L612" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.split_pdf-Tuple{Union{String, Vector{UInt8}}}' href='#MakieTeX.split_pdf-Tuple{Union{String, Vector{UInt8}}}'><span class="jlbinding">MakieTeX.split_pdf</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
split_pdf(pdf::Union{Vector{UInt8}, String})::Vector{UInt8}
```


Splits a PDF into its constituent pages, returning a Vector of UInt8 arrays, each representing a page.

The input must be a PDF file, either as a String or as a Vector{UInt8} of the PDF&#39;s bytes.

::: tip Warn

The input String does **NOT** represent a filename!

:::

This uses Ghostscript to actually split the PDF and return PDF files.  If you just want to render the PDF, use [`load_pdf`](/api#MakieTeX.load_pdf-Tuple{String}) and [`page2img`](/api#MakieTeX.page2img-Tuple{Union{CachedPDF,%20CachedTEX,%20CachedTypst},%20Int64}) instead.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/rendering/pdf_utils.jl#L68-L79" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.texdoc-Tuple{Any}' href='#MakieTeX.texdoc-Tuple{Any}'><span class="jlbinding">MakieTeX.texdoc</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
texdoc(contents::AbstractString; kwargs...)
```


A shorthand for `TEXDocument(contents, add_defaults=true; kwargs...)`.

Available keyword arguments are:
- `requires`: code which comes before `documentclass` in the preamble.  Default: `raw"\RequirePackage{luatex85}"`.
  
- `class`: the document class.  Default (and what you should use): `"standalone"`.
  
- `classoptions`: the options you should pass to the class, i.e., `\documentclass[$classoptions]{$class}`.  Default: `"preview, tightpage, 12pt"`.
  
- `preamble`: arbitrary code for the preamble (between `\documentclass` and `\begin{document}`).  Default: `raw"\usepackage{amsmath, xcolor} \pagestyle{empty}"`.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L265-L277" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.teximg' href='#MakieTeX.teximg'><span class="jlbinding">MakieTeX.teximg</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
teximg(tex; position, ...)
teximg!(ax_or_scene, tex; position, ...)
```


This recipe plots rendered `TeX` to your Figure or Scene.  

There are three types of input you can provide:
- Any `String`, which is rendered to LaTeX cognizant of the figure&#39;s overall theme,
  
- A [`TEXDocument`](/api#MakieTeX.TEXDocument) object, which is rendered to LaTeX directly, and can be customized by the user,
  
- A [`CachedTEX`](/api#MakieTeX.CachedTEX) object, which is a pre-rendered LaTeX document.
  

`tex` may be a single one of these objects, or an array of them.

**Plot type**

The plot type alias for the `teximg` function is `TeXImg`.

**Attributes**

**`align`** =  `(:center, :center)`  — Alignment of the rendered document relative to its `position`, as a `(halign, valign)` tuple of `:left`/`:center`/`:right` and `:top`/`:center`/`:bottom`.

**`clip_planes`** =  `@inherit clip_planes automatic`  — Clip planes offer a way to do clipping in 3D space. You can set a Vector of up to 8 `Plane3f` planes here, behind which plots will be clipped (i.e. become invisible). By default clip planes are inherited from the parent plot or scene. You can remove parent `clip_planes` by passing `Plane3f[]`.

**`depth_shift`** =  `0.0`  — Adjusts the depth value of a plot after all other transformations, i.e. in clip space, where `-1 <= depth <= 1`. This only applies to GLMakie and WGLMakie and can be used to adjust render order (like a tunable overdraw).

**`fxaa`** =  `true`  — Adjusts whether the plot is rendered with fxaa (fast approximate anti-aliasing, GLMakie only). Note that some plots implement a better native anti-aliasing solution (scatter, text, lines). For them `fxaa = true` generally lowers quality. Plots that show smoothly interpolated data (e.g. image, surface) may also degrade in quality as `fxaa = true` can cause blurring.

**`inspectable`** =  `@inherit inspectable`  — Sets whether this plot should be seen by `DataInspector`. The default depends on the theme of the parent scene.

**`inspector_clear`** =  `automatic`  — Sets a callback function `(inspector, plot) -> ...` for cleaning up custom indicators in DataInspector.

**`inspector_hover`** =  `automatic`  — Sets a callback function `(inspector, plot, index) -> ...` which replaces the default `show_data` methods.

**`inspector_label`** =  `automatic`  — Sets a callback function `(plot, index, position) -> string` which replaces the default label generated by DataInspector.

**`markerspace`** =  `:pixel`  — Space in which `markersize` is interpreted. See `Makie.spaces()`.

**`model`** =  `automatic`  — Sets a model matrix for the plot. This overrides adjustments made with `translate!`, `rotate!` and `scale!`.

**`overdraw`** =  `false`  — Controls if the plot will draw over other plots. This specifically means ignoring depth checks in GL backends

**`position`** =  `[Point2{Float32}(0)]`  — Position(s) at which to draw the document(s).

**`render_density`** =  `2`  — Density at which the rendered document is rasterised (1 means 1 px == 1 pt).

**`rotation`** =  `[0.0f0]`  — Counter-clockwise rotation in radians.

**`scale`** =  `1.0`  — Uniform scaling factor applied to the rendered document.

**`space`** =  `:data`  — Sets the transformation space for box encompassing the plot. See `Makie.spaces()` for possible inputs.

**`ssao`** =  `false`  — Adjusts whether the plot is rendered with ssao (screen space ambient occlusion). Note that this only makes sense in 3D plots and is only applicable with `fxaa = true`.

**`transformation`** =  `:automatic`  — Controls the inheritance or directly sets the transformations of a plot. Transformations include the transform function and model matrix as generated by `translate!(...)`, `scale!(...)` and `rotate!(...)`. They can be set directly by passing a `Transformation()` object or inherited from the parent plot or scene. Inheritance options include:
- `:automatic`: Inherit transformations if the parent and child `space` is compatible
  
- `:inherit`: Inherit transformations
  
- `:inherit_model`: Inherit only model transformations
  
- `:inherit_transform_func`: Inherit only the transform function
  
- `:nothing`: Inherit neither, fully disconnecting the child&#39;s transformations from the parent
  

Another option is to pass arguments to the `transform!()` function which then get applied to the plot. For example `transformation = (:xz, 1.0)` which rotates the `xy` plane to the `xz` plane and translates by `1.0`. For this inheritance defaults to `:automatic` but can also be set through e.g. `(:nothing, (:xz, 1.0))`.

**`transparency`** =  `false`  — Adjusts how the plot deals with transparency. In GLMakie `transparency = true` results in using Order Independent Transparency.

**`visible`** =  `true`  — Controls whether the plot gets rendered or not.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/Makie.jl/blob/v0.24.10/src/recipes.jl#L540-L622" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.teximg!' href='#MakieTeX.teximg!'><span class="jlbinding">MakieTeX.teximg!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



`teximg!` is the mutating variant of plotting function `teximg`. Check the docstring for `teximg` for further information.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/Makie.jl/blob/v0.24.10/src/recipes.jl#L542" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.try_tex_engine-Tuple{Cmd}' href='#MakieTeX.try_tex_engine-Tuple{Cmd}'><span class="jlbinding">MakieTeX.try_tex_engine</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Try to write to `engine` and see what happens


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/MakieTeX.jl#L56" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='MakieTeX.typst_doc-Tuple{Any}' href='#MakieTeX.typst_doc-Tuple{Any}'><span class="jlbinding">MakieTeX.typst_doc</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
typstdoc(contents::AbstractString; kwargs...)
```


A shorthand for `TypstDocument(contents, add_defaults=true; kwargs...)`.

Available keyword arguments are:
- `preamble`: arbitrary code inserted prior to the `contents`.  Default: `""`.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/MakieOrg/MakieTeX.jl/blob/e30d053f4962b1f2dc359488570f9e5e5178f389/src/types.jl#L323-L332" target="_blank" rel="noreferrer">source</a></Badge>

</details>

