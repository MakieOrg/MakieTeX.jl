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
    Typst_jll v0.11+ supports reading from `stdin`.
    Typst_jll v0.12+ will likely support writing to `stdout`.

    See also:
    https://github.com/typst/typst/issues/410
    https://github.com/typst/typst/pull/3339
    https://github.com/typst/typst/pull/3632
    =#
    return mktempdir() do dir
        cd(dir) do

            # First, create the typst file and write the document to it.
            touch("temp.typ")
            file = open("temp.typ", "w")
            path = "temp.pdf"
            print(file, document)
            close(file)

            # Now, we run the latexmk command in a pipeline so that we can redirect stdout and stderr to internal containers.
            # First we establish these pipelines:
            out = Pipe()
            err = Pipe()

            try
                # `pipeline` is not yet supported for `TypstCommand`
                redirect_stdio(stdout=out, stderr=err) do
                    run(ignorestatus(addenv(typst`compile temp.typ`, "TYPST_FONT_PATHS" => Typstry.julia_mono)))
                end

                close(out.in)
                close(err.in)
                if !isfile(path)
                    println("Typst did not write $(path)! Using Typst_jll.jl.")
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


compile_typst(doc::TypstDocument) = compile_typst(String(doc.doc))

typst2pdf(args...) = compile_typst(args...)
