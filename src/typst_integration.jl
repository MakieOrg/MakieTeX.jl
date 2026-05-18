# Integration with Makie's `text` recipe via the `text_handler` hook.
# Mirror of `text_integration.jl` for the Typst engine. When `text_handler`
# is set to a `Typst`, any `TypstString` going through `text()` — including
# Axis labels, titles, tick labels — is rendered with the Typst compiler
# instead of MathTeXEngine. Other input types fall through.

const _DEFAULT_TYPST_PREAMBLE = ""  # page sizing handled inside _compile_typst_block

"""
    AbstractTypst

Shared supertype for [`Typst`](@ref) (TypstString only) and
[`FullTypst`](@ref) (TypstString + plain strings).
"""
abstract type AbstractTypst <: AbstractPdfTextHandler end

"""
    Typst(; preamble, font, crop_margin_pt)

A `text_handler` for Makie's `text` recipe that renders `TypstString` content
with the Typst compiler. Pass to `set_theme!` / `with_theme` / a plot's
`text_handler` attribute. Plain `String` inputs fall through to the default
FreeType glyph layout. Use [`FullTypst`](@ref) to also route plain strings
through Typst.

# Fields

* `preamble` — Typst preamble. Default sets a transparent, auto-sized page.
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

# Compile inputs (color, fontsize, lineheight) are baked into the Typst source
# so the resulting PDF is already correctly sized and colored. We also emit a
# `<makietex-baseline>` metadata block holding the font-metric descender depth,
# which `typst query` will pull out after compilation. The metadata block has
# no layout effect (verified against `gs -sDEVICE=bbox`).
function _compile_typst_block(h::AbstractTypst, body::String, color, fontsize, lineheight)
    color_hex = Colors.hex(convert(RGB, Makie.to_color(color)))
    fs = Float32(fontsize)
    lh = Float32(lineheight)
    leading_pt = max(0.0f0, (lh - 1) * fs)
    font_line = h.font === nothing ? "" : "#set text(font: \"$(h.font)\")\n"

    # Strategy:
    # - Page margin = crop_margin_pt on all sides (anti-aliasing safety pad).
    # - `top-edge: "ascender", bottom-edge: "descender"` gives a content-
    #   independent line box: the bbox stays the same whether the body is
    #   "g" or "h", and there's room above cap-height for ascenders,
    #   diacritics, and accents without clipping.
    # - Pure math content (`$…$`) does NOT inherit those text edges, so a
    #   `#hide[Mp]` strut is prepended to establish text-line metrics on
    #   the line. `#h(-measure([Mp]).width)` retracts horizontally so the
    #   body starts at x=0 with no leading whitespace. Math taller than
    #   the strut's line grows the page naturally.
    # - Baseline is queried from "Mp" (constant for a given font/size).
    document = """
    #set page(width: auto, height: auto, margin: $(h.crop_margin_pt)pt, fill: none)
    $(h.preamble)
    $(font_line)#set text(
      size: $(fs)pt,
      fill: rgb("#$(color_hex)"),
      top-edge: "ascender",
      bottom-edge: "descender",
    )
    #set par(leading: $(leading_pt)pt)

    #context {
      let ref = [Mp]
      let h_total = measure(text(top-edge: "ascender", bottom-edge: "descender", ref)).height
      let h_above = measure(text(top-edge: "ascender", bottom-edge: "baseline",  ref)).height
      [#metadata((descent_pt: (h_total - h_above).pt())) <makietex-baseline>]
    }

    #context [#hide[Mp]#h(-measure([Mp]).width)$(body)]
    """

    pdf, baseline_pt = _compile_typst_capture_baseline(document, h.crop_margin_pt)
    return (CachedPDF(PDFDocument(pdf)), baseline_pt)
end

Makie.is_text_input(::TypstString) = true

# Empty / whitespace-only text shouldn't drive layout protrusions — the
# strut would otherwise emit a full cap-height+descender bbox even with
# nothing to render. Returning `nothing` makes Makie's text recipe fall
# through to the default (FreeType) path, which yields a 0-size bbox for
# empty input as expected.
_is_blank(s::AbstractString) = isempty(s) || all(isspace, s)

# Both variants accept TypstString. Explicit methods on concrete types avoid
# the (Full, AbstractString) vs (Abstract, TypstString) ambiguity that would
# arise with a single TypstString method on the abstract supertype.
Makie.compile_text(h::Typst, src::TypstString, color, fs, lh) =
    _is_blank(String(src)) ? nothing :
    _compile_typst_block(h, String(src), color, fs, lh)
Makie.compile_text(h::FullTypst, src::TypstString, color, fs, lh) =
    _is_blank(String(src)) ? nothing :
    _compile_typst_block(h, String(src), color, fs, lh)

# Only the Full variant claims plain strings.
Makie.compile_text(h::FullTypst, src::AbstractString, color, fs, lh) =
    _is_blank(src) ? nothing :
    _compile_typst_block(h, _escape_for_typst(src), color, fs, lh)

# Run typst once to produce the PDF, then a second `typst query` invocation
# to pull the baseline metadata. Both share the same TYPST_FONT_PATHS so
# Julia Mono is available without clobbering user-configured paths.
function _compile_typst_capture_baseline(document::String, crop_margin_pt::Real)
    return mktempdir() do dir
        cd(dir) do
            write("temp.typ", document)
            sep = Sys.iswindows() ? ";" : ":"
            fonts = haskey(ENV, "TYPST_FONT_PATHS") ?
                "$(ENV["TYPST_FONT_PATHS"])$(sep)$(Typstry.julia_mono)" :
                Typstry.julia_mono

            out = Pipe(); err = Pipe()
            try
                redirect_stdio(stdout = out, stderr = err) do
                    run(ignorestatus(addenv(typst`compile temp.typ`,
                        "TYPST_FONT_PATHS" => fonts)))
                end
            finally
                close(out.in); close(err.in)
            end
            if !isfile("temp.pdf")
                error("Typst compile failed:\n",
                      "stdout: ", read(out, String), "\n",
                      "stderr: ", read(err, String))
            end

            qout = Pipe()
            qerr = Pipe()
            try
                redirect_stdio(stdout = qout, stderr = qerr) do
                    run(ignorestatus(addenv(
                        typst`query temp.typ <makietex-baseline> --field value --one`,
                        "TYPST_FONT_PATHS" => fonts,
                    )))
                end
            finally
                close(qout.in); close(qerr.in)
            end
            payload = read(qout, String)
            m = match(r"descent_pt\"?\s*:\s*([-0-9.eE]+)", payload)
            baseline_pt = m === nothing ? 0.0f0 :
                max(0.0f0, parse(Float32, m.captures[1]))

            # No ink-cropping: Typst already sized the page tight to the
            # layout box + crop_margin_pt on all sides, so the page MediaBox
            # *is* what place_text! expects. baseline_pt is the descender,
            # which (combined with the margin already in cached.dims) gives
            # the correct baseline distance from the cropped ink bottom.
            return read("temp.pdf"), baseline_pt
        end
    end
end
