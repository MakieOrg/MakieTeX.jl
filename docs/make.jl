using Documenter, DocumenterVitepress

using MakieTeX

makedocs(;
    modules=[MakieTeX],
    format=DocumenterVitepress.MarkdownVitepress(; 
        repo = "https://github.com/MakieOrg/MakieTeX.jl"
    ),
    pages=[
        "Home" => "index.md",
        "Formats" => "formats.md",
        "API reference" => "api.md",
    ],
    sitename="MakieTeX.jl",
    authors="Anshul Singhvi",
    warnonly = true,
)

deploydocs(; 
    repo = "github.com/MakieOrg/MakieTeX.jl", 
    target = "build", 
    push_preview = true, 
    forcepush = true
)
