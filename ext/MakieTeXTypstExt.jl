module MakieTeXTypstExt

# Engine-side implementation of the `Typst` / `FullTypst` text handlers and
# the legacy `TypstDocument` / `CachedTypst` scatter-marker types. Triggered
# by `Typstry`, which brings `Typst_jll` in transitively.

using MakieTeX
using MakieTeX: AbstractTypst, Typst, FullTypst, CachedPDF, PDFDocument,
    TypstDocument, CachedTypst,
    _escape_for_typst, _is_blank,
    cached_doc, crop_pdf, page2img
using MakieTeX.Colors
using Makie
using Typstry
using Typstry: TypstString, typst

# --- Legacy scatter-marker path -------------------------------------------

# `compile_typst` returns the raw cropped PDF bytes from a Typst source string.
"""
    compile_typst(document::AbstractString)

Compile the given document as a String and return the resulting PDF.
"""
function compile_typst(document::AbstractString)
    return mktempdir() do dir
        cd(dir) do
            write("temp.typ", document)
            path = "temp.pdf"

            out = Pipe(); err = Pipe()
            try
                _separator = Sys.iswindows() ? ";" : ":"
                font_paths = haskey(ENV, "TYPST_FONT_PATHS") ?
                    "$(ENV["TYPST_FONT_PATHS"])$(_separator)$(Typstry.julia_mono)" :
                    Typstry.julia_mono
                redirect_stdio(stdout = out, stderr = err) do
                    run(ignorestatus(addenv(typst`compile temp.typ`,
                        "TYPST_FONT_PATHS" => font_paths)))
                end
                close(out.in); close(err.in)
                if !isfile(path)
                    println("Typst did not write $(path)!")
                    println("Files in temp directory: ", join(readdir(), ","))
                    printstyled("Stdout\n"; bold = true, color = :blue)
                    println(read(out, String))
                    printstyled("Stderr\n"; bold = true, color = :red)
                    println(read(err, String))
                    error()
                end
            finally
                return crop_pdf(path)
            end
        end
    end
end

compile_typst(doc::TypstDocument) = compile_typst(String(doc.contents))
typst2pdf(args...) = compile_typst(args...)

# CachedTypst constructors that need the engine.
MakieTeX.CachedTypst(doc::TypstDocument) = cached_doc(CachedTypst, typst2pdf, doc)
function MakieTeX.CachedTypst(str::Union{String, TypstString}; kwargs...)
    MakieTeX.CachedTypst(MakieTeX.TypstDocument(str); kwargs...)
end

# TypstDocument(::TypstString) — needs Typstry's `TypstString`.
MakieTeX.TypstDocument(ts::TypstString) = MakieTeX.TypstDocument(ts, true)

function MakieTeX.rasterize(ct::CachedTypst, scale::Int64 = 1)
    return page2img(ct, ct.doc.page; scale)
end

# --- `text_handler` path (Makie 0.25+ text recipe) ------------------------

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

            qout = Pipe(); qerr = Pipe()
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

            return read("temp.pdf"), baseline_pt
        end
    end
end

end # module
