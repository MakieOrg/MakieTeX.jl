using Documenter, DocumenterVitepress

using MakieTeX

makedocs(;
    modules=[MakieTeX],
    format=DocumenterVitepress.MarkdownVitepress(; repo = "https://github.com/asinghvi17/MakieTeX.jl"),
    pages=[
        "Home" => "index.md",
    ],
    edit_link="https://github.com/asinghvi17/MakieTeX.jl/blob/{commit}{path}#L{line}",
    sitename="MakieTeX.jl",
    authors="Anshul Singhvi",
    warnonly = true,
)
