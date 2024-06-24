using CairoMakie, MakieTeX
using Test, Downloads

@testset "TeX rendering" begin

    can_access_example = try
        Downloads.download("https://texample.net/media/tikz/examples/TEX/rotated-triangle.tex")
        true
    catch e
        false
        @warn "Cannot access texample.net; skipping tests that require it."
    end

    can_access_example && @testset "texample.net" begin

        mkpath(joinpath(example_path, "texample"))

        names = [
            "city",
            "planets",
            "model-physics",
            "smart-description",
            "or-gate",
            "polar-plot",
            "dominoes",
            "cielab",
        ]

        for name in names

            @testset "$name" begin
                render_texample(CachedTeX, TeXDocument,
                    "https://texample.net/media/tikz/examples/TEX/$name.tex")
            end

        end

        @testset "mandala" begin

            fig = Figure()

            @test_warn r"There were 7 pages in the document!  Selecting first page." LTeX(fig[1, 1], CachedTeX(TeXDocument(read(Downloads.download("https://texample.net/media/tikz/examples/TEX/mandala.tex"), String))))
            # @test_nowarn LTeX(fig[1, 1], CachedTeX(TeXDocument(read(Downloads.download("https://texample.net/media/tikz/examples/TEX/mandala.tex"), String))))

            resize_to_layout!(fig)

            filename = "mandala"

            save(joinpath(example_path, "texample", "$filename.png"), fig; px_per_unit=3)
            save(joinpath(example_path, "texample", "$filename.pdf"), fig; px_per_unit=1)

        end

    end

    # @testset "Rendering math and text" begin

    #     fig = Figure()


    #     @test_nowarn Label(fig[1, 1], LaTeXString(raw"This is Lorem Ipsum"))

    #     @test_nowarn Label(fig[1, 2], L"\iiint_a^{\mathbb{R}} \mathfrak D ~dt = \textbf{Poincar\'e quotient}")


    #     save_test("plaintex", fig)
    # end

    # @testset "aligns" begin

    #     mkpath(joinpath(example_path, "aligns"))

    #     f = Figure(size = (200, 200))
    #     lt = Label(f[1, 1], LaTeXString("Hello from Makie\\TeX{}!"))
    #     teximg = lt.blockscene.plots[1]

    #     for halign in (:left, :center, :right)
    #         for valign in (:top, :center, :bottom)
    #             @testset "$(halign), $(valign)" begin
    #                 @test_nowarn teximg.align = (halign, valign)
    #                 @test_nowarn save_test(joinpath("aligns", "$(halign)_$(valign)"), f)
    #             end
    #         end
    #     end
    # end

    @testset "Layouting" begin

        @testset "Logo" begin
            fig = Figure(figure_padding = 1, size = (1, 1))
            @test_nowarn LTeX(fig[1, 1], LaTeXString("Makie\\TeX.jl"))
            @test_nowarn resize_to_layout!(fig)

            save_test("logo", fig)

            @test true
        end
    end


    @testset "Corrupting Axis" begin

        fig = Figure(fontsize = 12, size = (300, 300))
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
        @test_nowarn lab = LTeX(fig[1, 1], td)

        @test_nowarn save_test("link", fig)
    end

    #=

    @testset "Integrating with Axis" begin
        fig = Figure(fontsize = 12, size = (300, 300))
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
                    fig = Figure(fontsize = 12, size = (300, 300))
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

        @testset "Rotated alignment for axis label" begin
            fig = Figure(; figure_padding = 100)
            ax1 = Axis(
                fig[1, 1];
                xtickformat = x -> latexstring.("a_{" .* string.(x) .* "}"),
                ylabel = L"\displaystyle \Phi(\vec x) = f(\vec x) + g(V)",
                #ylabelpadding = 15
            )
            heatmap!(ax1, Makie.peaks())
            scatter!(ax1.blockscene, ax1.blockscene.plots[end-6].plots[1].plots[1][1]; markersize = 10, color = :steelblue)

            @test_nowarn save_test("axislabel_align", fig)

        end

        @testset "Rotation" begin

            fig = Figure()
            ax = fig[1, 1] = Axis(fig)
            pos = (500, 500)
            posis = Point2f[]
            scatter!(ax, posis, markersize=10)
            for r in range(0, stop=2pi, length=20)
                p = pos .+ (sin(r) * 100.0, cos(r) * 100)
                push!(posis, p)
                text!(ax, L"test",
                    position=p,
                    textsize=50,
                    rotation=1.5pi - r,
                    align=(:center, :center)
                )
            end
            fig

            @test_nowarn save_test("rotation", fig)
        end

    end
    =#
end
