#=
# TeX rendering
=#

function rasterize(ct::CachedTEX, scale::Int64 = 1)
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
            path = "temp.pdf"
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
                if !isfile(path)
                    println("Latex did not write $(path)!  Using the $(tex_engine) engine.")
                    println("Files in temp directory are:\n" * join(readdir(), ','))
                    printstyled("Stdout\n", bold=true, color = :blue)
                    println(read(out, String))
                    printstyled("Stderr\n", bold=true, color = :red)
                    println(read(err, String))
                    error()
                end
            finally
                return crop_pdf(path)
            end
        end
    end
end


compile_latex(document::TEXDocument; kwargs...) = compile_latex(String(doc.doc); kwargs...)

latex2pdf(args...; kwargs...) = compile_latex(args...; kwargs...)
