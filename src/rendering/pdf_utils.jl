#=
# PDF utilities

This file contains a common core for working with PDFs.  It does not contain any rendering code,
but functions from here are used in the PDF and TeX rendering pipelines.
=#


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


"""
    get_pdf_bbox(path)

Get the bounding box of a PDF file using Ghostscript.
Returns a tuple representing the (xmin, ymin, xmax, ymax) of the bounding box.
"""
function get_pdf_bbox(path::String)
    !isfile(path) && error("File $(path) does not exist!")
    out = Pipe()
    err = Pipe()
    succ = success(pipeline(`$(Ghostscript_jll.gs()) -q -dBATCH -dNOPAUSE -sDEVICE=bbox $path`, stdout=out, stderr=err))

    close(out.in)
    close(err.in)
    result = read(err, String)
    if !succ
        println("Ghostscript failed to get the bounding box of $(path)!")
        println("Files in temp directory are:\n" * join(readdir(), ','))
        printstyled("Stdout\n", bold=true, color = :blue)
        println(result)
        printstyled("Stderr\n", bold=true, color = :red)
        println(read(err, String))
        error()
    end
    bbox_match = match(r"%%BoundingBox: ([0-9.]+) ([0-9.]+) ([0-9.]+) ([0-9.]+)", result)
    return parse.(Int, (
        bbox_match.captures[1],
        bbox_match.captures[2],
        bbox_match.captures[3],
        bbox_match.captures[4]
    ))
end

"""
    crop_pdf(path; margin = (0, 0, 0, 0))

Crop a PDF file using Ghostscript.  This alters the crop box but does not
actually remove elements.
"""
function crop_pdf(path::String; margin = _PDFCROP_DEFAULT_MARGINS[])
end
