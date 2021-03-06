
# MakieTeX

MakieTeX works by compiling a latex document and transforming it to a renderable
svg for CairoMakie or raster image for GLMakie. 

```julia
using GLMakie, MakieTeX
fig, ax, p = teximg(raw"\hat {f}(\xi )=\int _{-\infty }^{\infty }f(x)\ e^{-2\pi ix\xi }~ dx", textsize=100)
# Don't stretch the text 
ax.autolimitaspect[] = 1f0
autolimits!(ax)
fig
```
![teximg](https://user-images.githubusercontent.com/10947937/110216144-c5542480-7ead-11eb-9753-7ff215e36056.png)

```julia
using GLMakie MakieTeX
fig = Figure(resolution = (400, 300));
ax = Axis(fig[1, 1]);
hidexdecorations!(ax); hideydecorations!(ax);
tex = LTeX(fig[2, 1], raw"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}", textsize=20);
fig
```
![ltex](https://user-images.githubusercontent.com/10947937/110216157-d1d87d00-7ead-11eb-8507-62ddcff2a841.png)

There is a way to integrate LTeX into a legend, but it's pretty hacky now.  Ask on `#makie` in the JuliaLang Slack if you want to know.
![legendtex](https://user-images.githubusercontent.com/32143268/79641479-6adaa880-81b5-11ea-8138-4d6054ccfa6d.png)
