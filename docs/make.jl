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
    edit_link="https://github.com/JuliaPlots/MakieTeX.jl/blob/{commit}{path}#L{line}",
    sitename="MakieTeX.jl",
    authors="Anshul Singhvi",
    warnonly = true,
)
