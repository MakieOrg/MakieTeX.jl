using MakieTeX, CairoMakie
using Downloads
using Rsvg, Cairo

@testset "SVG rendering" begin
    svg = SVGDocument(read(Base.download("https://raw.githubusercontent.com/file-icons/icons/master/svg/Go-Old.svg"), String));
    bvsvg = SVGDocument(read(Base.download("https://upload.wikimedia.org/wikipedia/commons/6/6b/Bitmap_VS_SVG.svg"), String));
    wsvg = SVGDocument(read(Base.download("https://upload.wikimedia.org/wikipedia/en/8/80/Wikipedia-logo-v2.svg"), String));

    @test_nowarn csvg = CachedSVG(svg)
    @test_nowarn cbvsvg = CachedSVG(bvsvg)
    @test_nowarn cwsvg = CachedSVG(wsvg)

    f, a, p = scatter(Point2f(1); marker = csvg, markersize = 60, axis = (; limits = (0,2,0,2)))
    p.color = :red
    p.strokecolor = :blue
    p.strokewidth = 2
    save(joinpath(@__DIR__, "test_images", "gopher.svg"), f)
    save(joinpath(@__DIR__, "test_images", "gopher.png"), f)
    save(joinpath(@__DIR__, "test_images", "gopher.pdf"), f)

    ys = rand(10)
    f, a, p1 = scatter(ys; marker = wsvg, markersize = 30)
    p2 = scatter!(ys; marker = Circle, markersize = 30)
    translate!(p2, 0,0,-1)
    save(joinpath(@__DIR__, "test_images", "wikipedia.svg"), f)
    save(joinpath(@__DIR__, "test_images", "wikipedia.png"), f)
    save(joinpath(@__DIR__, "test_images", "wikipedia.pdf"), f)
    
end