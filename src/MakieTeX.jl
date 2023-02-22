module MakieTeX
using Makie, CairoMakie
using Cairo
using Colors, LaTeXStrings

# patch for Makie.jl block macro error
using Makie: CURRENT_DEFAULT_THEME

using Makie.GeometryBasics: origin, widths
using Makie.Observables
using DocStringExtensions

using Poppler_jll, Perl_jll, Ghostscript_jll, Glib_jll, tectonic_jll

# define some constants for configuration
"Render with Poppler pipeline (true) or Cairo pipeline (false)"
const RENDER_EXTRASAFE = Ref(false)
"The current `TeX` engine which MakieTeX uses."
const CURRENT_TEX_ENGINE = Ref{Cmd}(`lualatex`)
"Default margins for `pdfcrop`"
const _PDFCROP_DEFAULT_MARGINS = Ref{Vector{UInt8}}([0,0,0,0])
"Default density when rendering from calls to `text`"
const TEXT_RENDER_DENSITY = Ref(5)


include("types.jl")
include("rendering.jl")
include("recipe.jl")
include("text_override.jl")
include("layoutable.jl")

export TeXDocument, CachedTeX
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
    latexmk = Sys.which("latexmk")
    if isnothing(latexmk)
        @warn """
        MakieTeX could not find `latexmk` on your system!
        If you want to use the `luatex` engine, or any local or non-standard
        packages, then please install `latexmk` and ensure that it is on `PATH`.

        Defaulting to the bundled `tectonic` renderer for now.
        """
        CURRENT_TEX_ENGINE[] = `tectonic`
        return
    end

    t1 = try_tex_engine(CURRENT_TEX_ENGINE[])
    isnothing(t1) && return

    @warn("""
        The specified TeX engine $(CURRENT_TEX_ENGINE[]) is not available.
        Trying pdflatex:
        """
    )

    CURRENT_TEX_ENGINE[] = `pdflatex`

    t2 = try_tex_engine(CURRENT_TEX_ENGINE[])
    isnothing(t1) && return

    @warn "Could not find a TeX engine; defaulting to bundled `tectonic`"
    CURRENT_TEX_ENGINE[] = `tectonic`
    return
end

end # document
