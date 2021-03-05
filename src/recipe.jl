
@recipe(TeXImg, origin, tex) do scene
    merge(
        default_theme(scene),
        Attributes(
            color = AbstractPlotting.automatic,
            implant = true,
            dpi = 3000.0,
            align = (:left, :center)
        )
    )
end

function AbstractPlotting.convert_arguments(::Type{<: TeXImg}, bbox::T, x::AbstractString) where T <: Rect2D
    println("as")
    return (bbox, CachedTeX(implant_math(x)))
end

function AbstractPlotting.convert_arguments(::Type{<: TeXImg}, pos::T, x::AbstractString) where T <: Point2
    println("sa")
    doc = CachedTeX(implant_math(x))
    dims = doc.raw_dims
    return (Rect(pos..., dims.width, dims.height), CachedTeX(implant_math(x)))
end

function AbstractPlotting.convert_arguments(::Type{<: TeXImg}, bbox::RT, x::LaTeXString) where RT <: Rect2D
    if first(x) == "\$" && last(x) == "\$"
        return (bbox, CachedTeX(implant_math(x)))
    else
        return (bbox, CachedTeX(implant_text(x)))
    end
end

function AbstractPlotting.convert_arguments(::Type{<: TeXImg}, bbox::RT, doc::TeXDocument) where RT <: Rect2D
    println("doc")
    return (bbox, CachedTeX(doc))
end

function AbstractPlotting.convert_arguments(::Type{<: TeXImg}, pos::Point2, doc::CachedTeX)
    println("hi")
    dims = doc.raw_dims
    @info dims
    return (Rect(pos..., dims.width, dims.height), doc)
end

function AbstractPlotting.plot!(img::T) where T <: TeXImg

    bbox   = img[1]
    texdoc = img[2][]

    halign, valign = lift(first, img.align), lift(last, img.align)

    png = rsvg2img(texdoc.handle)

    xr, yr = Node{LinRange}(LinRange(0, 1, 10)), Node{LinRange}(LinRange(0, 1, 10))

    lift(bbox, halign, valign) do bbox, halign, valign
        x0, y0 = origin(bbox)
        w, h   = widths(bbox)


        if halign == :left
            x0 -= 0
        elseif halign == :center
            x0 -= w / 2
        elseif halign == :right
            x0 -= w
        end

        if valign == :top
            y0 -= h
        elseif valign == :center
            y0 -= h / 2
        elseif valign == :bottom
            y0 -= 0
        end

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

    ctx = screen.context
    tex = img[2][]
    halign, valign = img.align[]

    handle = svg2rsvg(tex.svg)
    dims = tex.raw_dims

    surf, rctx = rsvg2recordsurf(handle)
    x0, y0, w, h = get_ink_extents(surf)

    pos = CairoMakie.project_position(scene, origin(img[1][]), img.model[])
    scale_factor = CairoMakie.project_scale(scene, widths(bbox), img.model[])

    pos = if halign == :left
        pos .+ (0, 0)
    elseif halign == :center
        pos .+ (scale_factor[1] / w / 2, 0)
    elseif halign == :right
        pos .+ (scale_factor[1] / w, 0)
    end

    pos = if valign == :top
        pos .- (0, scale_factor[2] / h)
    elseif valign == :center
        pos .- (0, scale_factor[2] / h / 2)
    elseif valign == :bottom
        pos .- (0, 0)
    end



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
