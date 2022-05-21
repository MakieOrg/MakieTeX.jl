function dvisvg()
    if !isassigned(DVISVGM_PATH)
        DVISVGM_PATH = Sys.which("dvisvgm")
    end
    return DVISVGM_PATH[]
end


# The main compilation method - compiles arbitrary LaTeX documents
function compile_latex(
        document::AbstractString;
        tex_engine = CURRENT_TEX_ENGINE[],
        options = `-file-line-error -halt-on-error`,
        format = "dvi",
        read_format = format
    )

    use_tex_engine=tex_engine

    # First, we do some input checking.
    if !(format ∈ ("dvi", "pdf"))
        @error "Format must be either dvi or pdf; was $format"
    end
    formatcmd = ``
    if format == "dvi"
        if use_tex_engine==`lualatex`
            use_tex_engine=`dvilualatex`
        end
        # produce only dvi not pdf
        formatcmd = `-dvi -pdf-`
    else # format == "pdf"
        formatcmd = `-pdf`
    end

    # Unfortunately for us, Latexmk (which is required for any complex LaTeX doc)
    # does not like to compile straight to stdout, OR take in input from stdin;
    # it needs a file. We make a temporary directory for it to output to,
    # and create a file in there.
    return mktempdir() do dir
        cd(dir) do

            # First, create the tex file and write the document to it.
            touch("temp.tex")
            file = open("temp.tex", "w")
            print(file, document)
            close(file)

            # Now, we run the latexmk command in a pipeline so that we can redirect stdout and stderr to internal containers.
            # First we establish these pipelines:
            out = Pipe()
            err = Pipe()

            try
                latex = if tex_engine == `tectonic`
                    tectonic_jll.tectonic() do bin
                    	run(pipeline(ignorestatus(`$bin temp.tex`), stdout=out, stderr=err))
                    end
                else # latexmk
                    latex_cmd = `latexmk $options --shell-escape -latex=$use_tex_engine -cd -interaction=nonstopmode --output-format=$format $formatcmd temp.tex`
                    run(pipeline(ignorestatus(latex_cmd), stdout=out, stderr=err))
                end
                suc = success(latex)
                close(out.in)
                close(err.in)
                if !isfile("temp.$read_format")
                    println("Latex did not write temp.$(read_format)!  Using the $(tex_engine) engine.")
                    println("Files in temp directory are:\n" * join(readdir(), ','))
                    printstyled("Stdout\n", bold=true, color = :blue)
                    println(read(out, String))
                    printstyled("Stderr\n", bold=true, color = :red)
                    println(read(err, String))
                    error()
                end
            finally
                if format == "pdf"

                    if pdf_num_pages("temp.pdf") > 1
                        @warn("The PDF has more than 1 page!  Choosing the first page.")
                    end

                    # Generate the cropping margins
                    crop_margins = join(_PDFCROP_DEFAULT_MARGINS[], ' ')

                    # Convert engine from Latex to TeX - for example,
                    # Lua*LA*TeX => LuaTeX, ...
                    crop_engine = replace(string(tex_engine)[2:end-1], "la" => "")
                    crop_engine == `tectonic` && return read("temp.pdf", String)

                    pdfcrop = joinpath(@__DIR__, "pdfcrop.pl")
                    redirect_stderr(devnull) do
                        redirect_stdout(devnull) do
                            Ghostscript_jll.gs() do gs_exe
                                Perl_jll.perl() do perl_exe
                                    run(`$perl_exe $pdfcrop --margin $crop_margins $() --gscmd $gs_exe temp.pdf temp_cropped.pdf`)
                                end
                            end
                        end
                    end
                    return read("temp_cropped.pdf", String)
                else
                    return read("temp.$read_format", String)
                end
            end
        end
    end
end


compile_latex(document::TeXDocument; kwargs...) = compile_latex(convert(String, document); kwargs...)

latex2dvi(args...; kwargs...) = compile_latex(args...; format = "dvi", kwargs...)
latex2pdf(args...; kwargs...) = compile_latex(args...; format = "pdf", kwargs...)


# Pure poppler pipeline - directly from PDF to Cairo surface.

load_pdf(pdf::String) = load_pdf(Vector{UInt8}(pdf))

function load_pdf(pdf::Vector{UInt8})::Ptr{Cvoid} # Poppler document handle

    # Use Poppler to load the document.
    document = ccall(
        (:poppler_document_new_from_data, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid},
        (Ptr{Cchar}, Csize_t, Cstring, Ptr{Cvoid}),
        pdf, Csize_t(length(pdf)), C_NULL, C_NULL
    )

    if document == C_NULL
        error("The document at $path could not be loaded by Poppler!")
    end

    num_pages = pdf_num_pages(document)

    if num_pages != 1
        @warn "There were $num_pages pages in the document!  Selecting first page."
    end

    # Try to load the first page from the document, to test whether it is valid
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid},
        (Ptr{Cvoid}, Cint),
        document, 0 # page 0 is first page
    )

    if page == C_NULL
        error("Poppler was unable to read page 1 at index 0!  Please check your PDF.")
    end

    return document

    #
    # # Create a Cairo surface and context to render to
    # surf = Cairo.CairoRecordingSurface()
    # ctx  = Cairo.CairoContext(surf)
    # Cairo.save(ctx)
    # # Render the page to the surface
    # ccall(
    #     (:poppler_page_render_for_printing, Poppler_jll.libpoppler_glib),
    #     Cvoid,
    #     (Ptr{Cvoid}, Ptr{Cvoid}),
    #     page, ctx.ptr
    # )
    #
    # Cairo.restore(ctx)
    #
    # Cairo.flush(surf)
    #
    # return surf

end

# Rendering functions for the resulting Cairo surfaces and images

function firstpage2img(tex::CachedTeX; scale = 1, render_density = 1)
    document = tex.ptr
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid},
        (Ptr{Cvoid}, Cint),
        document, 0 # page 0 is first page
    )

    w = ceil(Int, tex.dims[1] * render_density)
    h = ceil(Int, tex.dims[2] * render_density)

    img = fill(Colors.ARGB32(1,1,1,0), w, h)

    surf = CairoImageSurface(img)

    ccall((:cairo_surface_set_device_scale, Cairo.libcairo), Cvoid, (Ptr{Nothing}, Cdouble, Cdouble),
        surf.ptr, render_density, render_density)

    ctx  = Cairo.CairoContext(surf)

    Cairo.set_antialias(ctx, Cairo.ANTIALIAS_BEST)

    Cairo.save(ctx)
    # Render the page to the surface
    ccall(
        (:poppler_page_render, Poppler_jll.libpoppler_glib),
        Cvoid,
        (Ptr{Cvoid}, Ptr{Cvoid}),
        page, ctx.ptr
    )

    Cairo.restore(ctx)

    Cairo.finish(surf)

    return (permutedims(img))

end


function firstpage2recordsurf(document::Ptr{Cvoid}; scale = 1, render_density = 1)
    w, h = pdf_get_page_size(document, 0)
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid},
        (Ptr{Cvoid}, Cint),
        document, 0 # page 0 is first page
    )

    surf = Cairo.CairoRecordingSurface()

    ctx  = Cairo.CairoContext(surf)

    Cairo.set_antialias(ctx, Cairo.ANTIALIAS_BEST)

    # Render the page to the surface
    ccall(
        (:poppler_page_render, Poppler_jll.libpoppler_glib),
        Cvoid,
        (Ptr{Cvoid}, Ptr{Cvoid}),
        page, ctx.ptr
    )

    Cairo.flush(surf)

    return surf

end


function recordsurf2img(tex::CachedTeX, render_density = 1)

    # We can find the final dimensions (in pixel units) of the Rsvg image.
    # Then, it's possible to store the image in a native Julia array,
    # which simplifies the process of rendering.
    # Cairo does not draw "empty" pixels, so we need to fill here
    w = ceil(Int, tex.dims[1] * render_density)
    h = ceil(Int, tex.dims[2] * render_density)

    img = fill(Colors.ARGB32(0,0,0,0), w, h)

    # Cairo allows you to use a Matrix of ARGB32, which simplifies rendering.
    cs = Cairo.CairoImageSurface(img)
    ccall((:cairo_surface_set_device_scale, Cairo.libcairo), Cvoid, (Ptr{Nothing}, Cdouble, Cdouble),
    cs.ptr, render_density, render_density)
    c = Cairo.CairoContext(cs)

    # Render the parsed SVG to a Cairo context


    # The image is rendered transposed, so we need to flip it.
    return rotr90(permutedims(img))
end

function render_surface(ctx::CairoContext, surf)
    Cairo.save(ctx)

    Cairo.set_source(ctx, surf,-0.0, 0.0)

    Cairo.paint(ctx)

    Cairo.restore(ctx)
    return
end



# Utility functions

function pdf_num_pages(filename::String)
    metadata = Poppler_jll.pdfinfo() do exe
        read(`$exe $filename`, String)
    end

    infos = split(metadata, '\n')

    ind = findfirst(x -> contains(x, "Pages"), infos)

    pageinfo = infos[ind]

    return parse(Int, split(pageinfo, ' ')[end])
end

function pdf_num_pages(document::Ptr{Cvoid})
    ccall(
        (:poppler_document_get_n_pages, Poppler_jll.libpoppler_glib),
        Cint,
        (Ptr{Cvoid},),
        document
    )
end

"""
    pdf_get_page_size(document::Ptr{Cvoid}, page_number::Int)::Tuple{Float64, Float64}

`document` must be a Poppler document handle.  Returns a tuple of `width, height`.
"""
function pdf_get_page_size(document::Ptr{Cvoid}, page_number::Int)

    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid},
        (Ptr{Cvoid}, Cint),
        document, page_number # page 0 is first page
    )

    if page == C_NULL
        error("Poppler was unable to read the page with index $page_number!  Please check your PDF.")
    end

    width = Ref{Cdouble}(0.0)
    height = Ref{Cdouble}(0.0)

    ccall((:poppler_page_get_size, Poppler_jll.libpoppler_glib), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Ptr{Cdouble}), page, width, height)

    return (width[], height[])
end


# This is the old pipeline, going from TeX to DVI to SVG, then using Rsvg to render
# Better boundingboxes actually, but worse...everything else


# DVI pipeline - LaTeX → DVI → SVG → Rsvg → Cairo
function dvi2svg(
        dvi::String;
        bbox = .2, # minimal bounding box
        options = ``
    )
    # dvisvgm will allow us to convert the DVI file into an SVG which
    # can be rendered by Rsvg.  In this case, we are able to provide
    # dvisvgm a DVI file from stdin, and receive a SVG string from
    # stdout.  This greatly simplifies the pipeline, and anyone with
    # a working TeX installation should have these utilities available.

    dvisvgm_cmd = Cmd(`$(dvisvg()) --bbox=$bbox --no-fonts --stdin --stdout $options`, env = ("LIBGS" => libgs(),))

    # We create an IO buffer to redirect stderr
    err = Pipe()

    dvisvgm = open(dvisvgm_cmd, "r+")

    redirect_stderr(err) do
        write(dvisvgm, dvi)
        close(dvisvgm.in)
    end

    return read(dvisvgm.out, String) # read the SVG in as a String


end

# PDF pipeline - LaTeX → PDF → SVG → Rsvg → Cairo
# Better in general
function pdf2svg(pdf::Vector{UInt8}; kwargs...)
    pdftocairo = Poppler_jll.pdftocairo() do exe
        open(`$exe -f 1 -l 1 -svg - -`, "r+")
    end

    write(pdftocairo, pdf)

    close(pdftocairo.in)

    return read(pdftocairo.out, String)
end

pdf2svg(pdf::String) = pdf2svg(Vector{UInt8}(pdf))

# SVG/RSVG functions
# Real simple stuff
#
# function svg2rsvg(svg::String, dpi = 72.0)
#     handle = Rsvg.handle_new_from_data(svg)
#     Rsvg.handle_set_dpi(handle, Float64(dpi))
#     return handle
# end
#
# function rsvg2recordsurf(handle::Rsvg.RsvgHandle)
#     surf = Cairo.CairoRecordingSurface()
#     ctx  = Cairo.CairoContext(surf)
#     Rsvg.handle_render_cairo(ctx, handle)
#     return (surf, ctx)
# end
#
