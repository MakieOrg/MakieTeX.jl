module MakieTeXLaTeXExt

# Engine-side implementation of the `LaTeX` text handler.
# Triggered by `tectonic_jll`; if `latexmk` is available on PATH it is
# preferred (matches the user's local TeX install / packages), and
# `tectonic_jll`'s bundled binary is used as a fallback otherwise.
#
# Type definitions, alignment math, and the bbox crop helpers all live in
# MakieTeX core. This extension only adds the engine-using methods.

using MakieTeX
using MakieTeX: LaTeX, PDF,
    CURRENT_TEX_ENGINE, _escape_for_text_mode, _hires_crop_pdf, _is_blank
using MakieTeX.Colors
using Makie
using Makie: LaTeXStrings
using Makie.LaTeXStrings: LaTeXString
using tectonic_jll

# Compile inputs (color, fontsize, lineheight) are baked into the LaTeX source
# so the resulting PDF is already correctly sized and colored. Inline LaTeX
# color/size commands override these in the natural way.
function _compile_latex_block(h::LaTeX, body::String, color, fontsize, lineheight)
    color_hex = Colors.hex(convert(RGB, Makie.to_color(color)))
    fs = Float32(fontsize)
    lh = Float32(lineheight)

    # `\vphantom{Ágy}` extends the saved box to the full font line metrics
    # (Á to capture ascender + accent overshoot, gy for descender) so the
    # bbox we hand back to Makie is content-independent — matches the
    # ascender/descender padding used by the FreeType and Typst handlers
    # instead of clinging to cap-height.
    # xcolor is loaded unconditionally so custom preambles don't have to
    # remember it — we always need \definecolor for the text color below.
    document = """
    \\RequirePackage{luatex85}
    \\documentclass[$(h.classoptions), border=$(h.crop_margin_pt)pt]{standalone}
    \\usepackage{xcolor}
    $(h.preamble)
    \\definecolor{maincolor}{HTML}{$(color_hex)}
    \\begin{document}
    \\newsavebox\\makietexbaselinebox%
    \\sbox\\makietexbaselinebox{%
    \\color{maincolor}\\fontsize{$(fs)pt}{$(fs * lh)pt}\\selectfont\\vphantom{Ágy}$(body)%
    }%
    \\typeout{MAKIETEX_BASELINE_DEPTH=\\the\\dp\\makietexbaselinebox}%
    \\usebox\\makietexbaselinebox
    \\end{document}
    """
    engine = h.engine === nothing ? CURRENT_TEX_ENGINE[] : h.engine
    pdf_bytes, baseline_pt = _compile_latex_capture_baseline(document, engine, h.crop_margin_pt)
    return (PDF(pdf_bytes), baseline_pt)
end

Makie.compile_text(h::LaTeX, src::LaTeXString, color, fontsize, lineheight) =
    _is_blank(String(src)) ? nothing :
    _compile_latex_block(h, String(src), color, fontsize, lineheight)

# `render_strings = true` claims plain `AbstractString` inputs too. Blank input
# returns `nothing` so empty Axis subtitles don't allocate phantom
# protrusion via a single-line LaTeX box.
Makie.compile_text(h::LaTeX, src::AbstractString, color, fontsize, lineheight) =
    (!h.render_strings || _is_blank(src)) ? nothing :
    _compile_latex_block(h, _escape_for_text_mode(src), color, fontsize, lineheight)

# Run latexmk/tectonic in a tempdir and parse `temp.log` for the box depth
# before tearing the dir down.
function _compile_latex_capture_baseline(document::String, engine::Cmd, crop_margin_pt::Real)
    return mktempdir() do dir
        cd(dir) do
            write("temp.tex", document)
            out = Pipe(); err = Pipe()
            try
                cmd = if engine == `tectonic`
                    # `--keep-logs` is needed so `temp.log` (which carries our
                    # `\typeout{MAKIETEX_BASELINE_DEPTH=…}` marker) survives the
                    # run; without it tectonic discards the log and the depth
                    # parses as 0, collapsing baseline alignment onto the ink
                    # bottom (visible as descenders sitting on the anchor).
                    `$(tectonic_jll.tectonic()) --keep-logs temp.tex`
                else
                    `latexmk -file-line-error --shell-escape -cd -$(engine) -interaction=nonstopmode temp.tex`
                end
                run(pipeline(ignorestatus(cmd), stdout = out, stderr = err))
            finally
                close(out.in); close(err.in)
            end
            log_text = isfile("temp.log") ? read("temp.log", String) : ""
            m = match(r"MAKIETEX_BASELINE_DEPTH=([-0-9.]+)pt", log_text)
            baseline_pt = m === nothing ? 0.0f0 : max(0.0f0, parse(Float32, m.captures[1]))
            # Use the natural standalone page (border = crop_margin_pt) so
            # the \vphantom-induced ascender padding survives. Cropping to
            # gs ink bbox would erase that and the bbox would slip back to
            # cap-height — exactly the divergence we're trying to fix.
            return read("temp.pdf"), baseline_pt
        end
    end
end

"Try to write to `engine` and see what happens."
function _try_tex_engine(engine::Cmd)
    try
        fd = open(engine; write = true)
        write(fd, "\n")
        close(fd)
        return nothing
    catch err
        return err
    end
end

function __init__()
    # Determine LaTeX engine support.
    latexmk = Sys.which("latexmk")
    if isnothing(latexmk)
        @warn """
        MakieTeXLaTeXExt could not find `latexmk` on your system!
        If you want to use the `luatex` engine, or any local or non-standard
        packages, please install `latexmk` and ensure that it is on `PATH`.

        Defaulting to the bundled `tectonic` renderer.
        """
        CURRENT_TEX_ENGINE[] = `tectonic`
        return
    end

    t1 = _try_tex_engine(CURRENT_TEX_ENGINE[])  # default `lualatex`
    if !isnothing(t1)
        @warn "The specified TeX engine $(CURRENT_TEX_ENGINE[]) is not available; trying pdflatex."
        CURRENT_TEX_ENGINE[] = `pdflatex`
    else
        return
    end

    t2 = _try_tex_engine(CURRENT_TEX_ENGINE[])
    if !isnothing(t2)
        @warn "Could not find a TeX engine; defaulting to bundled `tectonic`."
        CURRENT_TEX_ENGINE[] = `tectonic`
    end
    return
end

end # module
