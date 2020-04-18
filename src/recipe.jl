
@recipe(TeXImg, origin, tex) do scene
    merge(
        default_theme(scene),
        Attributes(
            color = AbstractPlotting.automatic,
            implant = true,
            dpi = 3000.0
        )
    )
end

function AbstractPlotting.convert_arguments(::Type{<: TeXImg}, bbox::RT, x::AbstractString) where RT <: Rect2D
    println("as")
    return (bbox, CachedTeX(implant_math(x)))
end

function AbstractPlotting.convert_arguments(::Type{<: TeXImg}, bbox::RT, x::LaTeXString) where RT <: Rect2D
    if first(x) == "\$" && last(x) == "\$"
        return (bbox, implant_math(x))
    else
        return (bbox, implant_text(x))
    end
end

function AbstractPlotting.convert_arguments(::Type{<: TeXImg}, bbox::RT, doc::TeXDocument) where RT <: Rect2D
    println("doc")
    return (bbox, CachedTeX(doc))
end

function AbstractPlotting.convert_arguments(::Type{<: TeXImg}, pos::Point2, doc::CachedTeX)
    dims = doc.raw_dims
    return (Rect(pos..., dims.width, dims.height), doc)
end

function AbstractPlotting.plot!(img::T) where T <: TeXImg

    bbox   = img[1]
    texdoc = img[2][]

    png = rsvg2img(texdoc.handle)

    xr, yr = Node{LinRange}(LinRange(0, 1, 10)), Node{LinRange}(LinRange(0, 1, 10))

    lift(bbox) do bbox
        x0, y0 = origin(bbox)
        w, h   = widths(bbox)
        xr[] = LinRange(x0, x0 + w, size(png, 1))
        yr[] = LinRange(y0, y0 + h, size(png, 2))
    end

    image!(img, xr, yr, png)
end

function get_ink_extents(surf::CairoSurface)
    dims = zeros(Float64, 4)

    ccall(
        (:cairo_recording_surface_ink_extents, CairoMakie.LIB_CAIRO),
        Cvoid,
        (Ptr{Cvoid}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}),
        surf.ptr, Ref(dims, 1), Ref(dims, 2), Ref(dims, 3), Ref(dims, 4)
    )

    return dims
end

function CairoMakie.draw_plot(scene::Scene, screen::CairoMakie.CairoScreen, img::T) where T <: MakieTeX.TeXImg

    bbox = AbstractPlotting.boundingbox(img)
    @show bbox

    ctx = screen.context

    pos = origin(img[1][])
    @show pos
    tex = img[2][]

    handle = svg2rsvg(tex.svg)
    dims = tex.raw_dims

    pos = CairoMakie.project_position(scene, pos, img.model[])
    @show pos
    @show dims

    surf, rctx = rsvg2recordsurf(handle)


    x0, y0, w, h = get_ink_extents(surf)

    @show (x0, y0, w, h)

    scale_factor = CairoMakie.project_scale(scene, widths(bbox), img.model[])

    @show scale_factor
    Cairo.save(ctx)
    Cairo.translate(
        ctx,
        pos[1],
        pos[2] - (h + y0) * scale_factor[2] / h
    )
    Cairo.scale(
        ctx,
        scale_factor[1] / w,
        scale_factor[2] / h
    )
    render_surface(ctx, surf)
    Cairo.restore(ctx)
end
