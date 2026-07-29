module MakieTeXTypstExt

# Engine-side implementation of the `Typst` / `FullTypst` text handlers.
# Triggered by `Typstry`, which brings `Typst_jll` in transitively.

using MakieTeX
using MakieTeX: Typst, PDF, CompiledPdfText,
    _escape_for_typst, _is_blank
using MakieTeX.Colors
using Makie
using Typstry
using Typstry: TypstString, typst

function _compile_typst_block(h::Typst, body::String, color, fontsize, lineheight)
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
    # - For inline / mixed / plain-text content, a `#hide[Mp]` strut is
    #   prepended (with `#h(-measure([Mp]).width)` retracting the cursor)
    #   to establish text-line metrics on the line. Content taller than
    #   the strut grows the page naturally. Display math (`$ … $`) is its
    #   own block — placing a strut would add an empty text line above it,
    #   so we skip the strut when the body is a single block equation.
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

    #context {
      let b = [$(body)]
      let is_block_eq = b.func() == math.equation and b.at("block", default: false)
      if is_block_eq { b } else { hide[Mp] + h(-measure([Mp]).width) + b }
    }
    """

    pdf, baseline_pt = _compile_typst_capture_baseline(document, h)
    return CompiledPdfText(PDF(pdf), baseline_pt, h.crop_margin_pt)
end

MakieTeX.compile_pdf_text(h::Typst, src::TypstString, fs, lh, color) =
    _compile_typst_block(h, String(src), color, fs, lh)

# `render_strings = true` claims plain `AbstractString` inputs too.
MakieTeX.compile_pdf_text(h::Typst, src::AbstractString, fs, lh, color) =
    h.render_strings ? _compile_typst_block(h, _escape_for_typst(src), color, fs, lh) : nothing

# Compile the document and run `typst query` to extract the baseline
# metadata. The handler's `font_paths` are prepended to the user's
# `TYPST_FONT_PATHS` (if set) before invoking the compiler.
function _compile_typst_capture_baseline(document::String, h::Typst)
    return mktempdir() do dir
        cd(dir) do
            write("temp.typ", document)
            sep = Sys.iswindows() ? ";" : ":"
            paths = String[h.font_paths...]
            haskey(ENV, "TYPST_FONT_PATHS") && push!(paths, ENV["TYPST_FONT_PATHS"])
            apply_env(cmd) = isempty(paths) ? cmd :
                addenv(cmd, "TYPST_FONT_PATHS" => join(paths, sep))

            # Capture through a file rather than a pipeline: a `TypstCommand` is not a
            # `Base.AbstractCmd`, and going through `Cmd` would drop Typstry's own run
            # handling.
            failure = nothing
            compile_output = mktemp() do path, io
                try
                    redirect_stdio(stdout = io, stderr = io) do
                        run(apply_env(typst`compile temp.typ`))
                    end
                catch e
                    failure = e
                end
                flush(io)
                return read(path, String)
            end
            MakieTeX.check_engine_pdf("temp.pdf", "typst", compile_output)
            failure === nothing || rethrow(failure)

            qpipe = Pipe()
            redirect_stdio(stdout = qpipe) do
                run(apply_env(typst`query temp.typ <makietex-baseline> --field value --one`))
            end
            close(qpipe.in)

            payload = read(qpipe, String)
            m = match(r"descent_pt\"?\s*:\s*([-0-9.eE]+)", payload)
            baseline_pt = m === nothing ? 0.0f0 :
                max(0.0f0, parse(Float32, m.captures[1]))

            return read("temp.pdf"), baseline_pt
        end
    end
end

end # module
