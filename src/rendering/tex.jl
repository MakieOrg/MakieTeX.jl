#=
# TeX rendering
=#

# Since `perl_jll` doesn't build for windows, we check for this, and try to substitute in the system's `perl` executable if possible.
@static if Sys.iswindows() # !hasproperty(Perl_jll, :perl)
    if isnothing(Sys.which("perl"))
        @warn "Perl not found!  MakieTeX will skip the cropping step during compilation!"
        mtperl(f) = nothing
    else
        function mtperl(f)
                f(`perl`)
        end
    end
else
    mtperl(f) = Perl_jll.perl(f)
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
                    tectonic_jll.tectonic() do bin
                        run(pipeline(ignorestatus(`$bin temp.tex`), stdout=out, stderr=err))
                    end
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
                crop_margins = join(_PDFCROP_DEFAULT_MARGINS[], ' ')

                # Convert engine from Latex to TeX - for example,
                # Lua*LA*TeX => LuaTeX, ...
                crop_engine = replace(string(tex_engine)[2:end-1], "la" => "")
                crop_engine == `tectonic` && return read("temp.pdf", String)

                pdfcrop = joinpath(dirname(@__DIR__), "pdfcrop.pl")
                new_pdf = redirect_stderr(devnull) do
                    redirect_stdout(devnull) do
                        Ghostscript_jll.gs() do gs_exe
                            mtperl() do perl_exe
                                # run(`$perl_exe $pdfcrop --margin $crop_margins --gscmd $gs_exe ./temp.pdf ./temp_cropped.pdf`)
                                cp("temp.pdf", "temp_cropped.pdf")
                                return read("temp_cropped.pdf", String)
                            end
                        end
                    end
                end
                if isnothing(new_pdf)
                    return read("temp.pdf", String)
                else
                    return new_pdf
                end
            end
        end
    end
end


compile_latex(document::TeXDocument; kwargs...) = compile_latex(convert(String, document); kwargs...)

latex2pdf(args...; kwargs...) = compile_latex(args...; kwargs...)
