using Documenter, MakieTeX

makedocs(;
    modules=[MakieTeX],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/asinghvi17/MakieTeX.jl/blob/{commit}{path}#L{line}",
    sitename="MakieTeX.jl",
    authors="Anshul Singhvi",
    assets=String[],
)
