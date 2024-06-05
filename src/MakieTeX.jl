module MakieTeX

using Makie
using Makie.MakieCore

using Colors, LaTeXStrings
using Base64

# Patch for Makie.jl `@Block` macro error
using Makie: CURRENT_DEFAULT_THEME

using Makie.GeometryBasics: origin, widths
using Makie.Observables
using DocStringExtensions

using Poppler_jll, Ghostscript_jll, Glib_jll, tectonic_jll
using Rsvg, Cairo

# Define some constants for configuration
"Render with Poppler pipeline (true) or Cairo pipeline (false)"
const RENDER_EXTRASAFE = Ref(false)
"The current `TeX` engine which MakieTeX uses."
const CURRENT_TEX_ENGINE = Ref{Cmd}(`lualatex`)
"Default margins for `pdfcrop`.  Private, try not to touch!"
const _PDFCROP_DEFAULT_MARGINS = Ref{Vector{UInt8}}([0,0,0,0])
"Default density when rendering images"
const RENDER_DENSITY = Ref(3)


include("types.jl")
include("recipe.jl")
include("text_utils.jl")
include("layoutable.jl")

include("rendering/pdf_utils.jl")
include("rendering/tex.jl")
include("rendering/pdf.jl")
include("rendering/svg.jl")

export Cached
export TeXDocument, CachedTeX
export PDFDocument, CachedPDF
export SVGDocument, CachedSVG
export dvi2svg, latex2dvi, rsvg2recordsurf, svg2rsvg
export teximg, teximg!, TeXImg
export LTeX

export LaTeXStrings, LaTeXString, latexstring, @L_str

"Try to write to `engine` and see what happens"
function try_tex_engine(engine::Cmd)
    try
        fd = open(engine; write = true)
        write(fd, "\n")
        close(fd)
        return nothing
    catch err
        println("The TeX engine $(CURRENT_TEX_ENGINE[]) failed.")
        return err
    end
end

"Checks whether the default latex engine is correct"
function __init__()

    # First, determine latex engine support
    latexmk = Sys.which("latexmk")
    if isnothing(latexmk)
        @warn """
        MakieTeX could not find `latexmk` on your system!
        If you want to use the `luatex` engine, or any local or non-standard
        packages, then please install `latexmk` and ensure that it is on `PATH`.

        Defaulting to the bundled `tectonic` renderer for now.
        """
        CURRENT_TEX_ENGINE[] = `tectonic`
    else
        t1 = try_tex_engine(CURRENT_TEX_ENGINE[]) # by default `lualatex`

        if !isnothing(t1)

            @warn("""
                The specified TeX engine $(CURRENT_TEX_ENGINE[]) is not available.
                Trying pdflatex:
                """
            )
    
            CURRENT_TEX_ENGINE[] = `pdflatex`
        else
            return
        end
    
        t2 = try_tex_engine(CURRENT_TEX_ENGINE[])
        if !isnothing(t2)
    
            @warn "Could not find a TeX engine; defaulting to bundled `tectonic`"
            CURRENT_TEX_ENGINE[] = `tectonic`
        else
            return
        end
    
    end

    return
end

end # document
