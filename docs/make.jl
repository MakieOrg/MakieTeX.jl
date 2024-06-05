using Documenter, DocumenterVitepress

using MakieTeX

makedocs(;
    modules=[MakieTeX],
    format=DocumenterVitepress.MarkdownVitepress(; 
        repo = "https://github.com/JuliaPlots/MakieTeX.jl"
    ),
    pages=[
        "Home" => "index.md",
        "API reference" => "api.md",
    ],
    sitename="MakieTeX.jl",
    authors="Anshul Singhvi",
    warnonly = true,
)
