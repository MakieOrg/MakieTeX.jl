# Typst text handler — type definitions only. The actual compilation lives
# in `MakieTeXTypstExt` (triggered by `Typstry`), so the engine
# dependencies stay optional.

const _DEFAULT_TYPST_PREAMBLE = ""

"""
    AbstractTypst

Shared supertype for [`Typst`](@ref) (TypstString only) and
[`FullTypst`](@ref) (TypstString + plain strings). The compilation methods
live in `MakieTeXTypstExt` — load `Typstry` to activate them.
"""
abstract type AbstractTypst <: AbstractPdfTextHandler end

"""
    Typst(; preamble, font, crop_margin_pt)

A `text_handler` for Makie's `text` recipe that renders `TypstString` content
with the Typst compiler. Pass to `set_theme!` / `with_theme` / a plot's
`text_handler` attribute. Plain `String` inputs fall through to the default
FreeType glyph layout. Use [`FullTypst`](@ref) to also route plain strings
through Typst.

Requires the `Typstry` package to be loaded — the actual rendering
pipeline lives in `MakieTeXTypstExt`.

# Fields

* `preamble` — Typst preamble. Default is empty.
* `font` — `nothing` (Typst's default) or a font family name set via
  `#set text(font: …)`. The bundled Julia Mono path is always added to
  `TYPST_FONT_PATHS` so user fonts and the default fall through.
* `crop_margin_pt` — safety pad around the ink so anti-aliased edges aren't
  clipped at the page boundary.
"""
Base.@kwdef struct Typst <: AbstractTypst
    preamble::String = _DEFAULT_TYPST_PREAMBLE
    font::Union{Nothing, String} = nothing
    crop_margin_pt::Float32 = 2.0f0
end

"""
    FullTypst(; preamble, font, crop_margin_pt)

Like [`Typst`](@ref), but also routes plain `AbstractString` inputs through
Typst (with markup-character escaping). Closest analogue to enabling LaTeX
for all text.
"""
Base.@kwdef struct FullTypst <: AbstractTypst
    preamble::String = _DEFAULT_TYPST_PREAMBLE
    font::Union{Nothing, String} = nothing
    crop_margin_pt::Float32 = 2.0f0
end

# Conservatively escape characters that introduce Typst markup in text mode.
function _escape_for_typst(s::AbstractString)
    return replace(
        s,
        '\\' => raw"\\",
        '#'  => raw"\#",
        '$'  => raw"\$",
        '*'  => raw"\*",
        '_'  => raw"\_",
        '`'  => raw"\`",
        '<'  => raw"\<",
        '>'  => raw"\>",
        '@'  => raw"\@",
        '='  => raw"\=",
        '~'  => raw"\~",
    )
end

# Blank text (empty or whitespace-only) shouldn't drive layout protrusions —
# the strut would otherwise emit a full asc+desc bbox even with nothing to
# render. compile_text returns `nothing` for blank input, falling through to
# FreeType which yields a 0-size bbox as expected.
_is_blank(s::AbstractString) = isempty(s) || all(isspace, s)
