using CairoMakie, MakieTeX
using Test, Downloads

url(name) = "https://raw.githubusercontent.com/typst/packages/main/packages/preview/cetz/0.2.2/gallery/$name.typ"

@testset "Typst rendering" begin

    names = [
        "karls-picture",
        "tree",
        "waves",
        "pie-chart",
        "plot",
        "barchart"
    ]

    can_access_example = try
        _url = url(first(names))
        Downloads.download(_url)
        true
    catch e
        false
        @warn "Cannot access $_url; skipping tests that require it."
    end

    can_access_example && @testset "cetz" begin

        for name in names

            @testset "$name" begin
                render_texample(CachedTypst, TypstDocument, url(name))
            end

        end

    end
end
