using MakieTeX, CairoMakie
using Downloads
using Rsvg, Cairo


svg = SVGDocument(read(Base.download("https://raw.githubusercontent.com/file-icons/icons/master/svg/Go-Old.svg"), String));
bvsvg = SVGDocument(read(Base.download("https://upload.wikimedia.org/wikipedia/commons/6/6b/Bitmap_VS_SVG.svg"), String));
wsvg = SVGDocument(read(Base.download("https://upload.wikimedia.org/wikipedia/en/8/80/Wikipedia-logo-v2.svg"), String));



csvg = CachedSVG(svg)
cbvsvg = CachedSVG(bvsvg)
cwsvg = CachedSVG(wsvg)

f, a, p = scatter(Point2f(1); marker = svg, markersize = 60, axis = (; limits = (0,2,0,2)))
p.color = :red
p.strokecolor = :blue
p.strokewidth = 2
f
ys = rand(10)
f, a, p1 = scatter(ys; marker = wsvg, markersize = 30)
p2 = scatter!(ys; marker = Circle, markersize = 30)
translate!(p2, 0,0,-1)
f