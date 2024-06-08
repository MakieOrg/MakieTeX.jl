#=
# Typst rendering
=#

function rasterize(ct::CachedTypst, scale::Int64 = 1)
    return page2img(ct, ct.doc.page; scale)
end

# The main compilation method - compiles arbitrary Typst documents
"""
    compile_typst(document::AbstractString)

Compile the given document as a String and return the resulting PDF (also as a String).
"""
function compile_typst(document::AbstractString)
    #=
    Typst_jll v0.11+ supports compiling from `stdin`.
    It does not yet support compiling to `stdout`.

    See also:
    https://github.com/typst/typst/issues/410
    https://github.com/typst/typst/pull/3339
    =#
    return mktempdir() do dir
        cd(dir) do

            # First, create the typst file and write the document to it.
            touch("temp.typ")
            file = open("temp.typ", "w")
            print(file, document)
            close(file)

            # Now, we run the latexmk command in a pipeline so that we can redirect stdout and stderr to internal containers.
            # First we establish these pipelines:
            out = Pipe()
            err = Pipe()

            try
                # `pipeline` is not yet supported for `TypstCommand`
                redirect_stdio(stdout=out, stderr=err) do
                    run(ignorestatus(typst`compile temp.typ`))
                end

                close(out.in)
                close(err.in)
                if !isfile("temp.pdf")
                    println("Typst did not write temp.pdf! Using the Typst_jll.jl.")
                    println("Files in temp directory are:\n" * join(readdir(), ','))
                    printstyled("Stdout\n", bold=true, color = :blue)
                    println(read(out, String))
                    printstyled("Stderr\n", bold=true, color = :red)
                    println(read(err, String))
                    error()
                end
            finally

                # if pdf_num_pages("temp.pdf") > 1
                #     @warn("The PDF has more than 1 page!  Choosing the first page.")
                # end

                # Generate the cropping margins
                bbox = get_pdf_bbox("temp.pdf")
                crop_box = (
                    bbox[1] - _PDFCROP_DEFAULT_MARGINS[][1],
                    bbox[2] - _PDFCROP_DEFAULT_MARGINS[][2],
                    bbox[3] + _PDFCROP_DEFAULT_MARGINS[][3],
                    bbox[4] + _PDFCROP_DEFAULT_MARGINS[][4],
                )
                crop_cmd = join(crop_box, " ")


                out = Pipe()
                err = Pipe()
                try
                    redirect_stderr(err) do
                        redirect_stdout(out) do
                            Ghostscript_jll.gs() do gs_exe
                                run(`$gs_exe -o temp_cropped.pdf -sDEVICE=pdfwrite -c "[/CropBox [$crop_cmd]" -c "/PAGES pdfmark" -f temp.pdf`)
                            end
                        end
                    end
                catch e
                finally
                close(out.in)
                close(err.in)
                if !isfile("temp_cropped.pdf")
                    println("`gs` failed to crop the PDF!")
                    println("Files in temp directory are:\n" * join(readdir(), ','))
                    printstyled("Stdout\n", bold=true, color = :blue)
                    println(read(out, String))
                    printstyled("Stderr\n", bold=true, color = :red)
                    println(read(err, String))
                    error()
                end
            end
                return isfile("temp_cropped.pdf") ? read("temp_cropped.pdf", String) : read("temp.pdf", String)
            end
        end
    end
end


compile_typst(doc::TypstDocument) = compile_typst(String(doc.doc))

typst2pdf(args...) = compile_typst(args...)
