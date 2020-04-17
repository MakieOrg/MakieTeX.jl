
@recipe(TeXImg, origin, tex) do scene
    merge(
        default_theme(scene),
        Attributes(
            color = AbstractPlotting.automatic,
            implant = true
        )
    )
end

function AbstractPlotting.plot!(img::T) where T <: TeXImg

    pos = img[1][]
    tex = img[2][]
    str = if img.implant[]
        implant_math(tex)
    else
        tex
    end

    svg = dvi2svg(latex2dvi(str))

    png = svg2img(svg)

    image!(img, png)
end

function get_ink_extents(surf::CairoSurface)
    x0 = [0.0]
    y0 = [0.0]
    w  = [0.0]
    h  = [0.0]

    ccall(
        (:cairo_recording_surface_ink_extents, CairoMakie.LIB_CAIRO),
        Cvoid,
        (Ptr{Cvoid}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}),
        surf.ptr, x0, y0, w, h
    )

    return (x0[1], y0[1], w[1], h[1])
end

function draw_plot(scene::Scene, screen::CairoMakie.CairoScreen, img::TeXImg)

    bbox = AbstractPlotting.boundingbox(img)

    ctx = screen.context

    pos = img[1][]
    tex = img[2][]
    str = if img.implant[]
        implant_math(tex)
    else
        tex
    end

    pos = CairoMakie.project_position(scene, pos, img.model[])

    svg = dvi2svg(latex2dvi(str))
    surf, cr = rsvg2recordsurf(svg2rsvg(svg))

    x0, y0, w, h = get_ink_extents(surf)

    @show((x0, y0, w, h))

    scale_factor = project_scale(scene, widths(bbox), img.model[])

    @show scale_factor
    Cairo.save(ctx)
    Cairo.translate(ctx, pos[1], pos[2] - (h + y0) * scale_factor[2] / h)
    Cairo.scale(ctx, scale_factor[1] / w, scale_factor[2] / h)
    render_surface(ctx, surf)
    Cairo.restore(ctx)
end
