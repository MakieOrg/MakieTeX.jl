# Typst

[`MakieTeX.Typst`](@ref) is a `text_handler` that routes `typst"…"` content through the [Typst](https://typst.app) compiler. Same shape as [LaTeX](@ref) — same `text_handler` slot, same `full` flag, same `preamble` field — but with Typst's much faster compile loop and modern math syntax.

## Quick start

```@example typst
using CairoMakie, MakieTeX, Typstry

with_theme(text_handler = MakieTeX.Typst()) do
    fig = Figure()
    ax = Axis(fig[1, 1];
        title  = typst"Damped oscillation $A(t) = e^(-lambda t) cos(omega t)$",
        xlabel = typst"time $t$ (s)",
        ylabel = typst"amplitude $A(t)$",
    )
    t = range(0, 10; length = 400)
    lines!(ax, t, exp.(-0.3 .* t) .* cos.(2π .* t))
    fig
end
```

Inline math uses single `$…$` with no surrounding whitespace; spaced `$ … $` is display math (block-level, taller).

## Full mode — match fonts across the whole figure

`full = true` routes plain `String`s through Typst as well, so every label uses the same font as the math:

```@example typst
with_theme(text_handler = MakieTeX.Typst(full = true)) do
    fig = Figure()
    ax = Axis(fig[1, 1];
        title  = typst"Damped oscillation $A(t) = e^(-lambda t) cos(omega t)$",
        xlabel = "time (seconds)",
        ylabel = "amplitude",
    )
    t = range(0, 10; length = 400)
    lines!(ax, t, exp.(-0.3 .* t) .* cos.(2π .* t); label = typst"$lambda = 0.3$")
    axislegend(ax)
    fig
end
```

Typst's compile loop is fast — full mode is generally cheap.

## Preambles — set fonts, define show rules, import templates

The `preamble` field is dropped at the top of every compiled Typst document. Good places to set the body font, configure math, or `#import` a template:

```@example typst
handler = MakieTeX.Typst(
    full = true,
    preamble = """
        #set text(font: "New Computer Modern")
        #let kB = math.italic("k") + sub("B")
    """,
)

with_theme(text_handler = handler) do
    fig = Figure()
    ax = Axis(fig[1, 1];
        title  = typst"Boltzmann distribution  $f(E) = exp(-E / (#kB T))$",
        xlabel = typst"energy $E$",
        ylabel = typst"$f(E)$",
    )
    E = range(0, 5; length = 200)
    lines!(ax, E, exp.(-E))
    fig
end
```

`#let` definitions, `#show` rules and `#import` of templates all work the same way.

`font` and `font_paths` are also available as direct constructor fields if you don't need a full preamble:

```julia
MakieTeX.Typst(font = "Inter", font_paths = ["/path/to/your/fonts"])
```

## Complex content in layouts

The handler flows through every Makie text element, including `Label`, so any Typst snippet is usable as a layout cell. Typst's `#import` can sit inline in the content block — no preamble plumbing needed. Same physics as on the [LaTeX](@ref) page, drawn with [`fletcher`](https://typst.app/universe/package/fletcher):

```@example typst
with_theme(text_handler = MakieTeX.Typst(full = true)) do
    fig = Figure(size = (760, 360))
    Label(fig[1, 1], typst"""
    #import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
    #diagram(
      spacing: 1.5cm,
      node((0, 0), $e^-$),
      node((0, 1), $e^+$),
      node((1, 0.5), $$, shape: "circle", fill: black, radius: 1.2mm),
      node((2, 0.5), $$, shape: "circle", fill: black, radius: 1.2mm),
      node((3, 0), $mu^-$),
      node((3, 1), $mu^+$),
      edge((0, 0), (1, 0.5), "-|>"),
      edge((1, 0.5), (0, 1), "-|>"),
      edge((1, 0.5), (2, 0.5), "wave", label: $gamma$),
      edge((2, 0.5), (3, 0), "-|>"),
      edge((3, 1), (2, 0.5), "-|>"),
    )
    """; fontsize = 16, tellheight = false)
    ax = Axis(fig[1, 2];
        title = typst"$e^-e^+ -> mu^-mu^+$ (tree level)",
        xlabel = typst"$cos theta$",
        ylabel = typst"$dif sigma slash dif cos theta$",
    )
    θ = range(-1, 1; length = 200)
    lines!(ax, θ, 1 .+ θ.^2; label = typst"$prop 1 + cos^2 theta$")
    axislegend(ax; position = :ct)
    fig
end
```

See the [API reference](@ref api) for the full set of options.
