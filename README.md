# <img src="https://user-images.githubusercontent.com/32143268/165514916-4337e55a-18ec-4831-ab0f-11ebcb679600.svg" alt="MakieTeX.jl" height="50" align = "top">
## <a href = "https://www.latex-project.org/"><img src="https://upload.wikimedia.org/wikipedia/commons/9/92/LaTeX_logo.svg" alt="LaTeX" height="30" align = "top"></a> integration for <a href = "https://www.github.com/JuliaPlots/Makie.jl"><img src="https://raw.githubusercontent.com/JuliaPlots/Makie.jl/master/assets/logo.png" alt="Makie.jl" height="30" align = "top"></a>

<img src="https://user-images.githubusercontent.com/32143268/169671023-4d4c8cf7-eb3d-4ee1-8634-8b73fa38d31c.svg" height=400></img>


MakieTeX allows you to draw and visualize arbitrary TeX documents in Makie!  You can insert anything from a single line of math to a large and complex TikZ diagram.

It works by compiling a stand-alone <img src="https://upload.wikimedia.org/wikipedia/commons/9/92/LaTeX_logo.svg" alt="LaTeX" height="20" align = "center"></a> document to PDF.  For CairoMakie, the PDF is read and rendered directly, and a raster image is rendered in GLMakie.

When loaded, MakieTeX will replace the handling of LaTeXStrings, which Makie natively performs with [`MathTeXEngine.jl`](https://github.com/Kolaru/MathTeXEngine.jl), with the MakieTeX pipeline.  This is significantly more time-consuming, so be warned - try not to `MakieTeX` for the axes of plots which you want to interact with!  Other things, which don't update as often, are fine.

### Quick start
```julia
using Makie, MakieTeX
using CairoMakie # or whichever other backend
fig = Figure()
l1 = Label(
    fig[1, 1], L"A \emph{convex} function $f \in C$ is \textcolor{blue}{denoted} as \tikz{\draw[line width=1pt, >->] (0, -2pt) arc (-180:0:8pt);}";
    tellwidth = false, tellheight = true
)
ax1 = Axis(
    fig[2, 1];
    xtickformat = x -> latexstring.("a_{" .* string.(x) .* "}"),
    ytickformat = x -> latexstring.(string.(x)),
    ylabel = L"\displaystyle \Phi(\vec x) = f(\vec x) + g(V)",
)
heatmap!(ax1, Makie.peaks())
fig
```
<img src="https://user-images.githubusercontent.com/32143268/169671109-9c849a7b-4f57-4184-a6bb-1199a76c77c5.svg" height=300></img>


Also note that as of Makie 0.17, you cannot _change_ the text rendering mode; this is to say, assigning a LaTeXString or TeXDocument to a `text` plot to which you have passed a String will not work as expected.  Consequently, you must provide any LaTeX you want to render _at construction_.  This is the reason why we have set the axis attributes within the constructor call.

You need not install anything for MakieTeX to work, since we ship a minimal TeX renderer called [`tectonic`](https://tectonic-typesetting.github.io/en-US/) (based on XeLaTeX).  This will download any missing packages when it encounters them the first time.  However, it will likely not know about any local packages or TEXMF paths, nor will it be able to render advanced features like TikZ graphs which require LuaTeX.  The latexmk/lualatex combination will also likely be faster, and able to use advanced features like calling to other languages with `pythontex` (oh, the heresy!)

MakieTeX also renders TeX in accordance with the theme - specifically, if one changes the text color or textsize, it will be reflected in the rendered TeX.  Wrapping the above code with `with_theme(theme_dark()) do ... end` yields:

<img src="https://user-images.githubusercontent.com/32143268/169671099-b7d21f55-1d0c-4422-90da-8bef99e07348.svg" height=300></img>



### Scaling TeX

MakieTeX always plots TeX to its stated dimensions.  This allows it to be extremely accurate and easily match font sizes, but it comes at a price - when using the standard text pipeline, latex results may look very small, especially with the default figure resolution.

We provide a layoutable object, `LTeX`, which aims to solve this.  `LTeX`s are for all intents and purposes the same as `Label`s, with two extra keywords:
- `scale = 1`, which literally scales the generated PDF by the provided factor;
- `render_density = 5`, which specifies how densely any PDF must be rendered for the image fallback.  This only really affects GLMakie and WGLMakie, so feel free to ignore it or set it to 1 for CairoMakie purposes.

An example follows:

```julia
fig = Figure(resolution = (400, 300));
tex1 = LTeX(fig[1, 1], L"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}", scale=1);
tex2 = LTeX(fig[2, 1], L"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}", scale=2);
fig
```
![latex](https://user-images.githubusercontent.com/32143268/169671194-fc81d086-26fd-462b-8348-789ba763dbbd.svg)


### Inner workings

MakieTeX provides high-level dispatches on `LaTeXString`s from the [`LaTeXStrings.jl`](github.com/stevengj/LaTeXStrings.jl) package, as well as some lower level types.

Any input is converted to a `TeXDocument`, which is then compiled to `CachedTeX`. This last type contains the compiled PDF and some pointers to in-memory versions of the PDF.  These are what MakieTeX eventually uses to plot to the screen.

When plotting arrays of LaTeXStrings, MakieTeX takes a more efficient pathway by batching the array into a multi-page `standalone` document.  This allows the relevant packages in LaTeX to be loaded once per array instead of once per string, and decreases the runtime of the README example by a sixth.

In general, we use the packages `amsmath, amssymb, amsfonts, esint, lmodern, fontenc, xcolor` in rendered latexstrings.  However, work is ongoing on a good API for users to provide arbitrary preamble code.

### Configuration

There are several configuration constants you can set in MakieTeX, stored as const `Ref`s.  These are:

```CURRENT_TEX_ENGINE[] = `lualatex` ``` - The current `TeX` engine which MakieTeX uses.  Will default to `tectonic` if `latexmk` and `lualatex` are inaccessible on your system.
```RENDER_EXTRASAFE[] = false``` - Render with Poppler pipeline (false) or Cairo pipeline (true).  The Poppler pipeline offers better rendering but may be slightly slower.
```_PDFCROP_DEFAULT_MARGINS[] = [0,0,0,0]``` - Default margins for `pdfcrop`.  Feel free to set this to `fill(1, 4)` or higher if you need looser margins.  The numbers are in the order `[<left>, <top>, <right>, <bottom>]`.
```TEXT_RENDER_DENSITY[] = 5``` - Default density when rendering from calls to `text`.  Useful only for GLMakie.


```julia
using GLMakie, Makie, MakieTeX
fig = Figure(resolution = (400, 300));
ax = Axis(fig[1, 1]);
lines!(rand(10), color = 1:10);
tex = LTeX(fig[2, 1], L"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}", scale=2);
fig
```
<img src="https://user-images.githubusercontent.com/10947937/110216157-d1d87d00-7ead-11eb-8507-62ddcff2a841.png"></img>

## Including full LaTeX documents

With the `TeXDocument` struct, you can feed in a String which contains a full LaTeX document, and show it at real scale in Makie!

This example is from [Texample.net](https://texample.net/tikz/examples/title-graphics/)
```julia
using MakieTeX, CairoMakie, Makie
td = TeXDocument(read(download("https://texample.net/media/tikz/examples/TEX/title-graphics.tex"), String))
fig = Figure()
lt = Label(fig[1, 1], td; tellheight=false)
ax = Axis(fig[1, 2])
lines!(ax, rand(10); color = 1:10)
fig
```
![makietex](https://user-images.githubusercontent.com/32143268/165130481-53ee0fe1-4c70-4453-b430-7a2ad37082f8.png)

## Cool graphics!


![2plots](https://user-images.githubusercontent.com/32143268/165445977-79fbb1fe-6bd5-47c9-9501-be6c1ae837b9.svg)

![cielab](https://user-images.githubusercontent.com/32143268/165446027-a5cae0e4-f48a-41de-8170-ab4059651bc9.svg)

![dominoes](https://user-images.githubusercontent.com/32143268/165446028-0504abf9-7362-48c0-a07a-19a5cf038de0.svg)

![or-gate](https://user-images.githubusercontent.com/32143268/165446029-93578a5e-7825-40cc-9c1b-573ecaa2630f.svg)

![planets](https://user-images.githubusercontent.com/32143268/165446030-15d8e53c-06b9-4fa9-8867-03a0449fa9dc.svg)

![rotated-triangle](https://user-images.githubusercontent.com/32143268/165446031-1502461b-8599-4d27-9526-9f1c4d4c8267.svg)

## Installation

Simply run:
```julia
import Pkg; Pkg.add("MakieTeX")
```
and watch the magic happen!


## The rendering pipeline

The standard rendering pipeline works as follows: the string is converted in to a TeXDocument, which is compiled to pdf using the given renderer, or `tectonic` if it does not exist.  The pdf file is then cropped using the `pdfcrop` Perl script (this is what requires `Perl_jll` and `Ghostscript_jll`).

This cropped PDF is then loaded by Poppler, accessed through `Poppler_jll.jl` and `libpoppler-glib`.  If using the Cairo backend, it is plotted directly to a surface; if using another backend, it is rasterized to an image, and plotted using `scatter` with image markers.  The alignment is in this case depicted by `marker_offset`.

Thus, you only need a TeX engine, preferably LuaTeX, installed on your system.  We don't automatically detect the TeX engine, though, so if you want to change that, set ``` MakieTeX.CURRENT_TEX_ENGINE[] = `xelatex` ``` (note the backticks in place of quotes) or some other engine, as long as it is compatible with `latexmk`.
