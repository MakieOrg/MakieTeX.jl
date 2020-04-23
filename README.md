# MakieTeX

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliaplots.org/MakieTeX.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaplots.org/MakieTeX.jl/dev)

```julia
using Makie, MakieTeX
teximg(Rect2(0, 0, 122, 24), raw"\hat {f}(\xi )=\int _{-\infty }^{\infty }f(x)\ e^{-2\pi ix\xi }~ dx")
```
![teximg](https://user-images.githubusercontent.com/32143268/79641464-5696ab80-81b5-11ea-902d-d65da76dfa69.png)

```julia
using MakieLayout, Makie, MakieTeX
scene, layout = layoutscene(resolution = (500, 200));
ax = layout[1, 1] = LAxis(scene);
hidexdecorations!(ax); hideydecorations!(ax);
tex = layout[2, 1] = MakieTeX.LTeX(scene, raw"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}");
scene
```
![ltex](https://user-images.githubusercontent.com/32143268/79641864-b42bf780-81b7-11ea-8958-407f6c732069.png)

There is a way to integrate LTeX into a legend, but it's pretty hacky now.  Ask on `#makie` in the JuliaLang Slack if you want to know.
![legendtex](https://user-images.githubusercontent.com/32143268/79641479-6adaa880-81b5-11ea-8138-4d6054ccfa6d.png)
