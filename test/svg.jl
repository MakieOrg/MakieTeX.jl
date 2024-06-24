using MakieTeX, CairoMakie
using Downloads
using Rsvg, Cairo
using CairoMakie.Colors

@testset "SVG rendering" begin
    svg = SVGDocument(read(Base.download("https://raw.githubusercontent.com/file-icons/icons/master/svg/Go-Old.svg"), String));
    bvsvg = SVGDocument(read(Base.download("https://upload.wikimedia.org/wikipedia/commons/6/6b/Bitmap_VS_SVG.svg"), String));
    wsvg = SVGDocument(read(Base.download("https://upload.wikimedia.org/wikipedia/en/8/80/Wikipedia-logo-v2.svg"), String));

    @test_nowarn CachedSVG(svg);
    csvg = CachedSVG(svg);
    @test_nowarn CachedSVG(bvsvg);
    cbvsvg = CachedSVG(bvsvg);
    @test_nowarn CachedSVG(wsvg);
    cwsvg = CachedSVG(wsvg);

    f, a, p = scatter(Point2f(1); marker = csvg, markersize = 60, axis = (; limits = (0,2,0,2)))
    p.color = :red
    p.strokecolor = :blue
    p.strokewidth = 2
    @test_nowarn save_test("gopher", f; backend = CairoMakie)

    ys = rand(10)
    @test_nowarn f, a, p1 = scatter(ys; marker = wsvg, markersize = 30)
    f, a, p1 = scatter(ys; marker = wsvg, markersize = 30)
    @test_nowarn p2 = scatter!(ys; marker = Circle, markersize = 30)
    p2 = scatter!(ys; marker = Circle, markersize = 30)
    @test_nowarn translate!(p2, 0,0,-1)
    translate!(p2, 0,0,-1)
    @test_nowarn save_test("wikipedia", f; backend = CairoMakie)

    @testset "SVG theming via CSS" begin
        # Test that the color is correct
        svg = SVGDocument(raw"""
        <svg width="300" height="130" xmlns="http://www.w3.org/2000/svg">
         <rect width="300" height="130" x="0" y="0" rx="20" ry="20"/>
        </svg>
        """)
        f, a, p = scatter(Point2f(1); marker = svg, markersize = 600, axis = (; limits = (0,2,0,2)))
        img = Makie.colorbuffer(f; backend = CairoMakie)
        @test Colors.red(img[end ÷ 2, end ÷ 2]) < 0.6
        p.strokewidth = 60
        p.strokecolor = :red
        img = Makie.colorbuffer(f; backend = CairoMakie)
        @test Colors.blue(img[end ÷ 4, end ÷ 2]) < 0.6
    end
end