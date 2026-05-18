# LaTeX text handler — type definitions only. The actual compilation lives
# in `MakieTeXLaTeXExt` (triggered by `tectonic_jll`), so the engine
# dependencies stay optional.

const _DEFAULT_LATEX_PREAMBLE = raw"""
\usepackage{amsmath, amsfonts, xcolor}
\pagestyle{empty}
\nopagecolor
"""
const _DEFAULT_LATEX_CLASSOPTIONS = "preview, tightpage"

"""
    LaTeX(; full, preamble, classoptions, engine, border_pt, crop_margin_pt)

A `text_handler` for Makie's `text` recipe that renders `LaTeXString` content
with a real LaTeX engine. Pass to `set_theme!` / `with_theme` / a plot's
`text_handler` attribute.

When `full = false` (default), plain `String` inputs fall through to the
default FreeType glyph layout. With `full = true`, plain strings are also
routed through LaTeX with appropriate text-mode escaping — analogous to
matplotlib's `rcParams["text.usetex"] = True`.

Requires the `tectonic_jll` package to be loaded — the actual rendering
pipeline lives in `MakieTeXLaTeXExt`.

# Fields

* `full` — `true` routes plain `AbstractString` inputs through LaTeX too.
* `preamble` — LaTeX preamble. Default loads `amsmath, amsfonts, xcolor` and
  sets a transparent page background.
* `classoptions` — `standalone` class options (without `border=`, which is
  appended from `border_pt`).
* `engine` — `nothing` (use the extension's default engine) or a `Cmd`.
* `border_pt` — pt margin in the page MediaBox; must exceed `crop_margin_pt`.
* `crop_margin_pt` — safety pad around the ink so anti-aliased edges aren't
  clipped at the page boundary.
"""
Base.@kwdef struct LaTeX <: AbstractPdfTextHandler
    full::Bool = false
    preamble::String = _DEFAULT_LATEX_PREAMBLE
    classoptions::String = _DEFAULT_LATEX_CLASSOPTIONS
    engine::Union{Nothing, Cmd} = nothing
    border_pt::Int = 3
    crop_margin_pt::Float32 = 2.0f0
end

function _escape_for_text_mode(s::AbstractString)
    return replace(
        s,
        '\\' => raw"\textbackslash{}",
        '{'  => raw"\{",
        '}'  => raw"\}",
        '$'  => raw"\$",
        '&'  => raw"\&",
        '#'  => raw"\#",
        '_'  => raw"\_",
        '%'  => raw"\%",
        '^'  => raw"\textasciicircum{}",
        '~'  => raw"\textasciitilde{}",
        '\n' => raw"\\",
    )
end

# Engine selection lives in MakieTeXLaTeXExt; the public API is the `engine`
# field on `LaTeX`. CURRENT_TEX_ENGINE is the extension-internal fallback
# used when `engine === nothing`.
const CURRENT_TEX_ENGINE = Ref{Cmd}(`lualatex`)
