# Changelog

## v0.5.0 - 2026-05-20

- Reworked MakieTeX around Makie 0.25's new `text_handler` hook (requires Makie ≥ 0.25) [#73](https://github.com/MakieOrg/MakieTeX.jl/pull/73).
  - **Breaking**: removed `teximg`, `LTeX`, the `Cached*` cache, and the `*Document` types (`TEXDocument`, `TypstDocument`, `SVGDocument`, `EPSDocument`, `PDFDocument`).
  - **Breaking**: `LaTeXString` / `TypstString` now need an explicit `text_handler = MakieTeX.LaTeX()` / `MakieTeX.Typst()` (`set_theme!`, `with_theme`, or per-plot) to route through the engine; `MathTeXEngine` is the default again.
  - **Breaking**: PDF and SVG vector markers are now `MakieTeX.PDF(path | bytes; page = 1)` and `MakieTeX.SVG(path | bytes)`. PDF `page` is 1-based. The old `Cached*` markers are gone.
  - **Breaking**: SVG markers no longer recolor via Makie's `color` — use Makie's built-in `BezierPath` SVG marker if you need that.
  - **Breaking**: dropped `RENDER_DENSITY`, `CURRENT_TEX_ENGINE`, and `RENDER_EXTRASAFE`. GPU textures rasterize at the screen's `px_per_unit`, with `MakieTeX.TEXTURE_RENDER_DENSITY[]` (default 2) as the minimum density.
