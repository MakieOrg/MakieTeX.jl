
# Pure poppler pipeline - directly from PDF to Cairo surface.

"""
    load_pdf(pdf::String)::Ptr{Cvoid}
    load_pdf(pdf::Vector{UInt8})::Ptr{Cvoid}

Loads a PDF file into a Poppler document handle.

Input may be either a String or a `Vector{UInt8}`, each representing the PDF file in memory.  

!!! warn
    The String input does **NOT** represent a filename!
"""
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

end

# Rendering functions for the resulting Cairo surfaces and images

"""
    page2img(tex::CachedTeX, page::Int; scale = 1, render_density = 1)

Renders the `page` of the given `CachedTeX` object to an image, with the given `scale` and `render_density`.

This function reads the PDF using Poppler and renders it to a Cairo surface, which is then read as an image.
"""
function page2img(tex::CachedTeX, page::Int; scale = 1, render_density = 1)
    document = tex.ptr
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid},
        (Ptr{Cvoid}, Cint),
        document, page # page 0 is first page
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
    # Render the page to the surface using Poppler
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

firstpage2img(tex; kwargs...) = page2img(tex, 0; kwargs...)

function page2recordsurf(document::Ptr{Cvoid}, page::Int; scale = 1, render_density = 1)
    w, h = pdf_get_page_size(document, page)
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid},
        (Ptr{Cvoid}, Cint),
        document, page # page 0 is first page
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

firstpage2recordsurf(tex; kwargs...) = page2recordsurf(tex, 0; kwargs...)

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
    render_surface(c, tex.surf)

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
"""
    pdf_num_pages(filename::String)::Int

Returns the number of pages in a PDF file located at `filename`, using the Poppler executable.
"""
function pdf_num_pages(filename::String)
    metadata = Poppler_jll.pdfinfo() do exe
        read(`$exe $filename`, String)
    end

    infos = split(metadata, '\n')

    ind = findfirst(x -> contains(x, "Pages"), infos)

    pageinfo = infos[ind]

    return parse(Int, split(pageinfo, ' ')[end])
end

"""
    pdf_num_pages(document::Ptr{Cvoid})::Int

`document` must be a Poppler document handle.  Returns the number of pages in the document.
"""
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

"""
    split_pdf(pdf::Union{Vector{UInt8}, String})::Vector{UInt8}

Splits a PDF into its constituent pages, returning a Vector of UInt8 arrays, each representing a page.

The input must be a PDF file, either as a String or as a Vector{UInt8} of the PDF's bytes.

!!! warn
    The input String does **NOT** represent a filename!

This uses Ghostscript to actually split the PDF and return PDF files.  If you just want to render the PDF, use [`load_pdf`](@ref) and [`page2img`](@ref) instead.
"""
function split_pdf(pdf::Union{Vector{UInt8}, String})
    mktempdir() do dir
        cd(dir) do
            write("temp.pdf", pdf)

            num_pages = pdf_num_pages("temp.pdf")

            pdfs = Vector{UInt8}[]
            sizehint!(pdfs, num_pages)
            redirect_stderr(devnull) do
                redirect_stdout(devnull) do
                    for i in 1:num_pages
                        Ghostscript_jll.gs() do gs
                            run(`$gs -q -dBATCH -dNOPAUSE -dFirstPage=$i -dLastPage=$i -sOutputFile=temp_$(lpad(i, 4, '0')).pdf -sDEVICE=pdfwrite temp.pdf`)
                            push!(pdfs, read("temp_$(lpad(i, 4, '0')).pdf"))
                            rm("temp_$(lpad(i, 4, '0')).pdf")
                        end
                    end
                end
            end

            return pdfs
        end
    end
end
