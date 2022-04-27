using MakieTeX
using MakieTeX.Makie, MakieTeX.CairoMakie

using Downloads

using Test

example_path = joinpath(@__DIR__, "test_images")
mkpath(example_path)

function render_texample(url)

    fig = Figure()

    lt = LTeX(fig[1, 1], CachedTeX(TeXDocument(read(Downloads.download(url), String))))

    @test true

    resize_to_layout!(fig)

    filename = splitdir(splitext(url)[1])[2]

    save(joinpath(example_path, "$filename.png"), fig; px_per_unit=3)
    save(joinpath(example_path, "$filename.pdf"), fig; px_per_unit=1)
    save(joinpath(example_path, "$filename.svg"), fig; px_per_unit=0.75)

    @test true

end
@testset "MakieTeX.jl" begin

    @testset "texample.net" begin
        names = [
            "rotated-triangle",
            "city",
            "planets",
            "model-physics",
            "smart-description",
            "or-gate",
            "polar-plot",
            "dominoes",
            "cielab"
        ]

        for name in names

            @testset "$name" begin
                render_texample("https://texample.net/media/tikz/examples/TEX/$name.tex")
            end

        end

        @testset "mandala" begin

            fig = Figure()

            @test_warn r"The PDF has more than 1 page!  Choosing the first page." LTeX(fig[1, 1], CachedTeX(TeXDocument(read(Downloads.download("https://texample.net/media/tikz/examples/TEX/mandala.tex"), String))))

            resize_to_layout!(fig)

            filename = "mandala"

            save(joinpath(example_path, "$filename.png"), fig; px_per_unit=3)
            save(joinpath(example_path, "$filename.pdf"), fig; px_per_unit=1)

        end

    end

    @testset "Rendering math and text" begin

        fig = Figure()


        @test_nowarn LTeX(fig[1, 1], "This is Lorem Ipsum")

        @test_nowarn LTeX(fig[1, 2], L"\iiint_a^{\mathbb{R}} \mathfrak D ~dt = \textbf{Poincar\'e quotient}")


        save(joinpath(example_path, "plaintex.png"), fig; px_per_unit=3)
        save(joinpath(example_path, "plaintex.pdf"), fig; px_per_unit=1)
        save(joinpath(example_path, "plaintex.svg"), fig; px_per_unit=0.75)
    end
end
