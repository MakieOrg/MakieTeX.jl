using MakieTeX
using MakieTeX.Makie, MakieTeX.CairoMakie

using Downloads

using Test

example_path = joinpath(@__DIR__, "test_images")
mkpath(example_path)

function save_test(filename, fig)

    save(joinpath(example_path, "$filename.png"), fig; px_per_unit=3)
    save(joinpath(example_path, "$filename.pdf"), fig; px_per_unit=1)
    save(joinpath(example_path, "$filename.svg"), fig; px_per_unit=0.75)

end

function render_texample(url)

    fig = Figure()

    lt = Label(fig[1, 1], CachedTeX(TeXDocument(read(Downloads.download(url), String))))

    @test true

    resize_to_layout!(fig)

    filename = splitdir(splitext(url)[1])[2]

    save_test(joinpath(texample, filename), fig)

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

            @test_warn r"The PDF has more than 1 page!  Choosing the first page." Label(fig[1, 1], CachedTeX(TeXDocument(read(Downloads.download("https://texample.net/media/tikz/examples/TEX/mandala.tex"), String))))

            resize_to_layout!(fig)

            filename = "mandala"

            save(joinpath(example_path, "texample", "$filename.png"), fig; px_per_unit=3)
            save(joinpath(example_path, "texample", "$filename.pdf"), fig; px_per_unit=1)

        end

    end

    @testset "Rendering math and text" begin

        fig = Figure()


        @test_nowarn Label(fig[1, 1], LaTeXString(raw"This is Lorem Ipsum"))

        @test_nowarn Label(fig[1, 2], L"\iiint_a^{\mathbb{R}} \mathfrak D ~dt = \textbf{Poincar\'e quotient}")


        save_test("plaintex", fig)
    end

    @testset "aligns" begin

        mkpath(joinpath(example_path, "aligns"))

        f = Figure(resolution = (200, 200))
        lt = Label(f[1, 1], LaTeXString("Hello from Makie\\TeX{}!"))
        teximg = lt.blockscene.plots[1]

        for halign in (:left, :center, :right)
            for valign in (:top, :center, :bottom)
                @testset "$(halign), $(valign)" begin
                    @test_nowarn teximg.align = (halign, valign)
                    @test_nowarn save_test("$(halign)_$(valign)", f)
                end
            end
        end
    end

    @testset "Layouting" begin

        @testset "Logo" begin
            fig = Figure(figure_padding = 1, resolution = (1, 1))
            @test_nowarn Label(fig[1, 1], LaTeXString("Makie\\TeX.jl"))
            @test_nowarn resize_to_layout!(fig)

            save_test("logo", fig)

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
        @test_nowarn x_label = LTeX(gl[3, 2], L"$t$ (time)", tellheight = true, tellwidth = false)
        @test_nowarn y_label = LTeX(gl[2, 1], L"\int_a^t f(\tau) ~d\tau"; rotation = pi/2, tellheight = false, tellwidth = true)
        @test_nowarn title = LTeX(gl[1, 2], "\\Huge {\\LaTeX} title", tellheight = true, tellwidth = false)

        rowgap!(gl, 2, 1)
        colgap!(gl, 1, 5)

        save_test("corrupted_axis", fig)

        @test true

    end

    @testset "Integrating with Axis" begin
        fig = Figure(fontsize = 12, resolution = (300, 300))
        ax = Axis(
            fig[1,1];
            xlabel = LaTeXString("time (\$t\$) in arbitrary units"),
            ylabel = LaTeXString("here we go fellas"),
            title  = LaTeXString(raw"A \emph{convex} function $f \in C$ is \textcolor{blue}{denoted} as \tikz{\draw[line width=1pt, >->] (0, -2pt) arc (-180:0:8pt);}"),
            xtickformat = x -> latexstring.("a_{" .* string.(x) .* "}"),
        )
        # plot to the axis
        heatmap!(ax, Makie.peaks())

        @test_nowarn save_test("integrated_axis", fig)

        @test true
    end

    @testset "Links" begin
        td = TeXDocument(raw"""
        \documentclass{standalone}
        \usepackage{hyperref}
        \hypersetup{
            colorlinks=true,
            linkcolor=blue,
            filecolor=magenta,
            urlcolor=cyan,
        }
        \begin{document}
        \href{http://www.overleaf.com}{Something
        Linky} or go to the next url: \url{http://www.overleaf.com} or open \\

        the next file \href{run:./file.txt}{File.txt} or \href{tel:8008008000}{call someone}\\

        or \href{mailto:anshulsinghvi@gmail.com}{email me}
        \end{document}
        """)

        fig = Figure()
        @test_nowarn lab = Label(fig[1, 1], td)

        @test_nowarn save_test("link", fig)
    end

    @testset "Text override" begin
        @testset "Font scaling" begin
            @test_nowarn begin
                fig = Figure(); l = l = Label(fig[1, 1], Makie.LaTeXString(raw"""A function that is convex is \raisebox{-2pt}{\tikz{\draw[line width=1pt, >->] (0, 0) arc (-180:0:8pt);}}
            """), textsize=16); fig
            end
        end
        @testset "Theming" begin
            @test_nowarn begin
                fig = with_theme(theme_dark()) do
                    fig = Figure(fontsize = 12, resolution = (300, 300))
                    ax = Axis(
                        fig[1,1];
                        xlabel = LaTeXString("time (\$t\$) in arbitrary units"),
                        ylabel = LaTeXString("here we go fellas"),
                        title  = LaTeXString(raw"A \emph{convex} function $f \in C$ is \textcolor{blue}{denoted} as \tikz{\draw[line width=1pt, >->] (0, -2pt) arc (-180:0:8pt);}"),
                        xtickformat = x -> latexstring.("a_{" .* string.(x) .* "}"),
                    )
                    # plot to the axis
                    heatmap!(ax, Makie.peaks(); colormap = :inferno)
                    fig
                end
                @test_nowarn save_test("theming", fig)
            end
        end

        @testset "Rotation" begin
        end

    end

end
