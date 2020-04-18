# MakieTeX

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://asinghvi17.github.io/MakieTeX.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://asinghvi17.github.io/MakieTeX.jl/dev)
[![Build Status](https://gitlab.com/asinghvi17/MakieTeX.jl/badges/master/build.svg)](https://gitlab.com/asinghvi17/MakieTeX.jl/pipelines)
[![Coverage](https://gitlab.com/asinghvi17/MakieTeX.jl/badges/master/coverage.svg)](https://gitlab.com/asinghvi17/MakieTeX.jl/commits/master)

```julia
using Makie, MakieTeX
teximg(Rect2(0, 0, 122, 24), raw"\hat {f}(\xi )=\int _{-\infty }^{\infty }f(x)\ e^{-2\pi ix\xi }~ dx")
```
![](tex.png)
