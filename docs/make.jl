using Documenter, DocumenterVitepress
using MakieTeX

# Load the engine extensions so the LaTeX / Typst handlers work in @example
# blocks.
using tectonic_jll
using Typstry

makedocs(;
    modules = [MakieTeX],
    format = DocumenterVitepress.MarkdownVitepress(;
        repo = "https://github.com/MakieOrg/MakieTeX.jl",
    ),
    pages = [
        "Home" => "index.md",
        "LaTeX" => "latex.md",
        "Typst" => "typst.md",
        "PDF & SVG" => "pdf_svg.md",
        "API reference" => "api.md",
    ],
    sitename = "MakieTeX.jl",
    authors = "Anshul Singhvi, Julius Krumbiegel, and contributors",
    warnonly = get(ENV, "CI", "false") != "true",
    checkdocs = :public,
)

DocumenterVitepress.deploydocs(;
    repo = "github.com/MakieOrg/MakieTeX.jl",
    target = "build",
    push_preview = true,
    forcepush = true,
)
