# <img src="https://user-images.githubusercontent.com/32143268/165514916-4337e55a-18ec-4831-ab0f-11ebcb679600.svg" alt="MakieTeX.jl" height="50" align = "top">
## <a href = "https://www.latex-project.org/"><img src="https://upload.wikimedia.org/wikipedia/commons/9/92/LaTeX_logo.svg" alt="LaTeX" height="30" align = "top"></a> integration for <a href = "https://www.github.com/JuliaPlots/Makie.jl"><img src="https://raw.githubusercontent.com/JuliaPlots/Makie.jl/master/assets/logo.png" alt="Makie.jl" height="30" align = "top"></a>

<img src="https://user-images.githubusercontent.com/32143268/165445977-79fbb1fe-6bd5-47c9-9501-be6c1ae837b9.svg" height=250></img>


MakieTeX allows you to draw and visualize arbitrary TeX documents in Makie!  You can insert anything from a single line of math to a large and complex TikZ diagram.

It works by compiling a stand-alone <img src="https://upload.wikimedia.org/wikipedia/commons/9/92/LaTeX_logo.svg" alt="LaTeX" height="12" align = "top"></a> document to PDF.  For CairoMakie, the PDF is read and rendered directly, and a raster image is rendered in GLMakie.

When loaded, MakieTeX will replace the handling of LaTeXStrings, which Makie natively performs with [`MathTeXEngine.jl`](https://github.com/Kolaru/MathTeXEngine.jl), with the MakieTeX pipeline.  This is significantly more time-consuming, so be warned - try not to `MakieTeX` for the axes of interactive plots!  Other things, which don't update as often, are fine.

### Quick start
```julia
fig = Figure()
l1 = Label(
    fig[1, 1], L"A \emph{convex} function $f \in C$ is \textcolor{blue}{denoted} as \tikz{\draw[line width=1pt, >->] (0, -2pt) arc (-180:0:8pt);}";
    tellwidth = false, tellheight = true
)
ax1 = Axis(
    fig[2, 1];
    xtickformat = x -> latexstring.("a_{" .* string.(x) .* "}"),
    ylabel = L"\displaystyle \Phi(\vec x) = f(\vec x) + g(V)",
    ylabelpadding = 15
)
heatmap!(ax1, Makie.peaks())
fig
```

In order for MakieTeX to work, you should have `latexmk` and a TeX engine (preferably `LuaTeX`) installed.  If not, MakieTeX will default to using the shipped `tectonic` renderer (from [`Tectonic_jll`]), which uses `XeLaTeX` on the backend


```julia
using GLMakie, Makie, MakieTeX
fig = Figure(resolution = (400, 300));
ax = Axis(fig[1, 1]);
lines!(rand(10), color = 1:10);
tex = LTeX(fig[2, 1], L"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}", scale=2);
fig
```
<img src="https://user-images.githubusercontent.com/10947937/110216157-d1d87d00-7ead-11eb-8507-62ddcff2a841.png"></img>

```julia
using GLMakie, Makie, MakieTeX, LaTeXStrings
fig, ax, p = teximg(L"\hat {f}(\xi )=\int _{-\infty }^{\infty }f(x)\ e^{-2\pi ix\xi }~ dx", scale=10)
# Don't stretch the text
ax.aspect = DataAspect()
fig
```

<img src="https://user-images.githubusercontent.com/10947937/110216144-c5542480-7ead-11eb-9753-7ff215e36056.png" height=300></img>

There is a way to integrate LTeX into a legend, but it's pretty hacky now.  Ask on `#makie` in the JuliaLang Slack if you want to know.

<img src="https://user-images.githubusercontent.com/32143268/79641479-6adaa880-81b5-11ea-8138-4d6054ccfa6d.png" height=300></img>

You can also use MakieTeX to "replace" labels and titles with LaTeX, although it's a little hacky!

```julia
using CairoMakie, MakieTeX
fig = Figure(fontsize = 12, resolution = (300, 300))
# Create a GridLayout for the axis and labels
gl = fig[1, 1] = GridLayout()
# Create the Axis within this layout, leave space for the title and labels
ax = Axis(gl[2,2])
# plot to the axis
lines!(ax, rand(10); color = rand(RGBAf, 10))

# create labels and title
x_label = LTeX(gl[3, 2], raw"$t$ (time)", tellheight = true, tellwidth = false)
y_label = LTeX(gl[2, 1], L"\int_a^t f(\tau) ~d\tau"; rotation = pi/2, tellheight = false, tellwidth = true)
title = LTeX(gl[1, 2], "\\Huge {\\LaTeX} title", tellheight = true, tellwidth = false)

rowgap!(gl, 2, 1)
colgap!(gl, 1, 5)

fig
```
<img src="https://user-images.githubusercontent.com/32143268/165825392-63de2e69-eb86-42b9-a946-c9ffe727a28f.svg" height=300></img>


## Including full LaTeX documents

With the `TeXDocument` struct, you can feed in a String which contains a full LaTeX document, and show it at real scale in Makie!

This example is from [Texample.net](https://texample.net/tikz/examples/title-graphics/)
```julia
using MakieTeX, CairoMakie, Makie
td = TeXDocument(read(download("https://texample.net/media/tikz/examples/TEX/title-graphics.tex"), String))
fig = Figure()
lt = LTeX(fig[1, 1], td; tellheight=false)
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

In order to run the latest code, you should check out the master branch of this repo and the master branch of Makie.  You can do this by:

```
]add Makie#master MakieTeX#master
```


## The rendering pipeline

The standard rendering pipeline works as follows: the string is converted in to a TeXDocument, which is compiled to pdf (by default, using system lualatex).  The pdf file is then cropped using the `pdfcrop` Perl script (this requires Perl_jll and Ghostscript_jll).

This cropped PDF is then loaded by Poppler, accessed through `Poppler_jll.jl` and libpoppler-glib, and rendered to a Cairo surface.  From here, if CairoMakie is the backend, we can render directly to the surface.  For any other backend, we render an ARGB image and, then plot that.

Thus, you only need a TeX engine, preferably LuaTeX, installed on your system.  We don't automatically detect the TeX engine, though, so if you want to change that, set ``` MakieTeX.CURRENT_TEX_ENGINE[] = `xelatex` ``` (note the backticks in place of quotes) or some other engine, as long as it is compatible with `latexmk`.
