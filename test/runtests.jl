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

    save(joinpath(example_path, "texample", "$filename.png"), fig; px_per_unit=3)
    save(joinpath(example_path, "texample", "$filename.pdf"), fig; px_per_unit=1)
    save(joinpath(example_path, "texample", "$filename.svg"), fig; px_per_unit=0.75)

    @test true

end


@testset "MakieTeX.jl" begin

    @testset "texample.net" begin

        mkpath(joinpath(example_path, "texample"))

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

            save(joinpath(example_path, "texample", "$filename.png"), fig; px_per_unit=3)
            save(joinpath(example_path, "texample", "$filename.pdf"), fig; px_per_unit=1)

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

    @testset "aligns" begin

        mkpath(joinpath(example_path, "aligns"))

        f = Figure(resolution = (200, 200))
        lt = LTeX(f[1, 1], raw"Hello from Makie\TeX{}!")
        teximg = lt.blockscene.plots[1]

        for halign in (:left, :center, :right)
            for valign in (:top, :center, :bottom)
                @testset "$(halign), $(valign)" begin
                    @test_nowarn teximg.align = (halign, valign)
                    @test_nowarn save(joinpath(example_path, "aligns", "$(halign)_$(valign).png"), f; px_per_unit = 3)
                    @test_nowarn save(joinpath(example_path, "aligns", "$(halign)_$(valign).svg"), f; px_per_unit = 1)
                    @test_nowarn save(joinpath(example_path, "aligns", "$(halign)_$(valign).pdf"), f; px_per_unit = 0.75)
                end
            end
        end
    end

    @testset "Layouting" begin

        @testset "Logo" begin
            fig = Figure(figure_padding = 1, resolution = (1, 1))
            @test_nowarn LTeX(fig[1, 1], "Makie\\TeX.jl")
            @test_nowarn resize_to_layout!(fig)

            save(joinpath(example_path, "logo.png"), fig; px_per_unit=3)
            save(joinpath(example_path, "logo.pdf"), fig; px_per_unit=1)
            save(joinpath(example_path, "logo.svg"), fig; px_per_unit=0.75)

            @test true
        end
    end


    @testset "Corrupting Axis" begin

        fig = Figure(fontsize = 12, resolution = (300, 300))
        # Create a GridLayout for the axis and labels
        gl = fig[1, 1] = GridLayout()
        # Create the Axis within this layout, leave space for the title and labels
        ax = Axis(gl[2,2])
        # plot to the axis
        lines!(ax, rand(10); color = rand(RGBAf, 10))

        # create labels and title
        @test_nowarn x_label = LTeX(gl[3, 2], raw"$t$ (time)", tellheight = true, tellwidth = false)
        @test_nowarn y_label = LTeX(gl[2, 1], L"\int_a^t f(\tau) ~d\tau"; rotation = pi/2, tellheight = false, tellwidth = true)
        @test_nowarn title = LTeX(gl[1, 2], "\\Huge {\\LaTeX} title", tellheight = true, tellwidth = false)

        rowgap!(gl, 2, 1)
        colgap!(gl, 1, 5)

        save(joinpath(example_path, "corrupted_axis.png"), fig; px_per_unit=3)
        save(joinpath(example_path, "corrupted_axis.pdf"), fig; px_per_unit=1)
        save(joinpath(example_path, "corrupted_axis.svg"), fig; px_per_unit=0.75)

        @test true

    end

end
