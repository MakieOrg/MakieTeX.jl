#=
# TeX rendering
=#

function rasterize(ct::CachedTeX, scale::Int64 = 1)
    return page2img(ct, ct.doc.page; scale)
end

# The main compilation method - compiles arbitrary LaTeX documents
"""
    compile_latex(document::AbstractString; tex_engine = CURRENT_TEX_ENGINE[], options = `-file-line-error`)

Compile the given document as a String and return the resulting PDF (also as a String).
"""
function compile_latex(
    document::AbstractString;
    tex_engine = CURRENT_TEX_ENGINE[],
    options = `-file-line-error`
)

    use_tex_engine=tex_engine

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
                    run(pipeline(ignorestatus(`$(tectonic_jll.tectonic()) temp.tex`), stdout=out, stderr=err))
                else # latexmk
                    latex_cmd = `latexmk $options --shell-escape -cd -$use_tex_engine -interaction=nonstopmode temp.tex`
                    run(pipeline(ignorestatus(latex_cmd), stdout=out, stderr=err))
                end
                suc = success(latex)
                close(out.in)
                close(err.in)
                if !isfile("temp.pdf")
                    println("Latex did not write temp.pdf!  Using the $(tex_engine) engine.")
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


compile_latex(document::TeXDocument; kwargs...) = compile_latex(doc.doc; kwargs...)

latex2pdf(args...; kwargs...) = compile_latex(args...; kwargs...)
