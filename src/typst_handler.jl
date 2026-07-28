# Typst text handler — type definitions only. The actual compilation lives
# in `MakieTeXTypstExt` (triggered by `Typstry`), so the engine
# dependencies stay optional.

"""
    Typst(; render_strings, preamble, font, font_paths, crop_margin_pt)

A `text_handler` for Makie's `text` recipe that renders `TypstString` content
with the Typst compiler. Pass to `set_theme!` / `with_theme` / a plot's
`text_handler` attribute.

When `render_strings = false` (default), plain `String` inputs fall through to the
default FreeType glyph layout. With `render_strings = true`, plain strings are also
routed through Typst (with markup-character escaping).

Requires the `Typstry` package to be loaded — the actual rendering
pipeline lives in `MakieTeXTypstExt`.

# Fields

* `render_strings` — `true` routes plain `AbstractString` inputs through Typst too.
* `preamble` — Typst preamble. Default is empty.
* `font` — `nothing` (Typst's default) or a font family name set via
  `#set text(font: …)`.
* `font_paths` — extra directories added to `TYPST_FONT_PATHS` so Typst can
  pick up custom fonts. Prepended to whatever is already in the env var.
* `crop_margin_pt` — safety pad around the ink so anti-aliased edges aren't
  clipped at the page boundary.
"""
Base.@kwdef struct Typst <: AbstractPdfTextHandler
    render_strings::Bool = false
    preamble::String = ""
    font::Union{Nothing, String} = nothing
    font_paths::Vector{String} = String[]
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

# Blank text (empty or whitespace-only) shouldn't drive layout protrusions — the
# strut would otherwise emit a full asc+desc bbox even with nothing to render.
# `emit_text` returns an empty block for these; see `_is_blank_text`.
_is_blank(s::AbstractString) = isempty(s) || all(isspace, s)
