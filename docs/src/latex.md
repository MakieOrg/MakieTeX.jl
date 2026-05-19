# LaTeX

[`MakieTeX.LaTeX`](@ref) is a `text_handler` that routes `LaTeXString` content through a real LaTeX engine (tectonic / lualatex / pdflatex) instead of Makie's in-process `MathTeXEngine.jl` approximation.

Why use it:

- Math that uses LaTeX packages MathTeX doesn't cover — `physics`, `siunitx`, `mhchem`, `chemfig`, custom macros.
- Publication-quality output: real glyph metrics, real kerning, hairlines stay vector on CairoMakie.
- One handler can serve a whole figure (or theme), so fonts match across every element.

## Quick start

Pass a `MakieTeX.LaTeX()` handler via `with_theme`, `set_theme!`, or as a per-plot `text_handler` keyword. `L"…"` strings then route through LaTeX; plain `String`s keep Makie's default FreeType path:

```@example latex
using CairoMakie, MakieTeX, tectonic_jll

with_theme(text_handler = MakieTeX.LaTeX()) do
    fig = Figure(size = (600, 380), fontsize = 18)
    ax = Axis(fig[1, 1];
        title  = L"Damped oscillation $A(t) = e^{-\lambda t}\cos(\omega t)$",
        xlabel = L"time $t$ (s)",
        ylabel = L"amplitude $A(t)$",
    )
    t = range(0, 10; length = 400)
    lines!(ax, t, exp.(-0.3 .* t) .* cos.(2π .* t))
    fig
end
```

`with_theme(...) do … end` keeps the handler scoped to a single figure. `set_theme!(text_handler = …)` makes it the default for the rest of the session.

## Full mode — match fonts across the whole figure

By default, plain strings (axis label text, tick labels, …) render with FreeType, so they look subtly different from the LaTeX-rendered math. `full = true` routes **every** text element through LaTeX, including tick labels and legend entries — analogous to matplotlib's `rcParams["text.usetex"] = True`:

```@example latex
with_theme(text_handler = MakieTeX.LaTeX(full = true)) do
    fig = Figure(size = (600, 380), fontsize = 18)
    ax = Axis(fig[1, 1];
        title  = L"Damped oscillation $A(t) = e^{-\lambda t}\cos(\omega t)$",
        xlabel = "time (seconds)",
        ylabel = "amplitude",
    )
    t = range(0, 10; length = 400)
    lines!(ax, t, exp.(-0.3 .* t) .* cos.(2π .* t); label = L"$\lambda = 0.3$")
    axislegend(ax)
    fig
end
```

The tradeoff is compile time — every distinct string runs through LaTeX once and is cached.

## Preambles — bring your own packages and macros

The `preamble` field is dropped into the LaTeX document before `\begin{document}`, so you can `\usepackage{...}` anything LaTeX supports and define macros:

```@example latex
handler = MakieTeX.LaTeX(
    full = true,
    preamble = raw"""
        \usepackage{amsmath, amssymb}
        \usepackage{physics}
        \usepackage{siunitx}
        \newcommand{\E}{\mathrm{e}}
    """,
)

with_theme(text_handler = handler) do
    fig = Figure(size = (600, 380), fontsize = 18)
    ax = Axis(fig[1, 1];
        title  = L"Free-electron density of states $\dv{n}{E} = \frac{V}{2\pi^2}\left(\frac{2m}{\hbar^2}\right)^{3/2}\sqrt{E}$",
        xlabel = L"energy $E\,(\si{\eV})$",
        ylabel = L"$\dv{n}{E}\,(\si{\per\eV})$",
    )
    E = range(0, 5; length = 200)
    lines!(ax, E, sqrt.(E))
    fig
end
```

Macros (`\E` here) and unit shortcuts work in any `L"…"` string while the handler is active.

## Engine

`MakieTeX.LaTeX()` picks an engine automatically — `latexmk` on `PATH` if available (uses your local TeX install), otherwise the bundled `tectonic_jll`. Override explicitly:

```julia
MakieTeX.LaTeX(engine = `lualatex`)        # via latexmk
MakieTeX.LaTeX(engine = `pdflatex`)
MakieTeX.LaTeX(engine = `tectonic`)        # bundled, no local TeX install needed
```

See the [API reference](@ref api) for the full set of options.
