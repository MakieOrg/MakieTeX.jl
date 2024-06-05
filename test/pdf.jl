using CairoMakie, MakieTeX
using Test

demo_pie = begin
    fig = Figure(; size = (100, 100), figure_padding = 0)
    ax = Axis(fig[1, 1])
    hidedecorations!(ax)
    hidespines!(ax)
    pie!(ax, [1, 2, 3, 4], color = Makie.wong_colors()[1:4], label = ["a", "b", "c", "d"], vertex_per_deg = 10)
    fig
end

pie_pdf = mktempdir() do dir
    save(joinpath(dir, "pie.pdf"), demo_pie)
    read(joinpath(dir, "pie.pdf"), String)
end

@test_nowarn display(scatter(rand(10); marker = PDFDocument(pie_pdf), markersize = 60); backend = CairoMakie)
@test_nowarn display(teximg(PDFDocument(pie_pdf)); backend = CairoMakie)
# @test_nowarn display(scatter(rand(10); marker = PDFDocument(pie_pdf)); backend = GLMakie)

