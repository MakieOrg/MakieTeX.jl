
@recipe(TeXImg, tex) do scene
    merge(
        default_theme(scene),
        Attributes(
            color = Makie.automatic,
            implant = true,
            render_density = 1,
            align = (:center, :center),
            scale = 1.0,
            position = Point3{Float32}(0),
            rotation = 0f0,
            space = :data,
        )
    )
end

function Makie.convert_arguments(::Type{<: TeXImg}, x::AbstractString)
    return (CachedTeX(implant_text(x)),)
end

function Makie.convert_arguments(::Type{<: TeXImg}, doc::TeXDocument)
    return (CachedTeX(doc),)
end

function Makie.plot!(plot::T) where T <: TeXImg
    # image to draw
    # We always want to draw this at a 1:1 ratio, so increasing textsize or
    # changing dpi should rerender
    img = map(plot[1], plot.render_density, plot.scale) do cachedtex, render_density, scale
        firstpage2img(cachedtex; render_density = render_density * scale)
    end

    # Rect to draw in
    # This is mostly aligning
    xr = Observable(0.0..1.0)
    yr = Observable(0.0..1.0)
    lift(img, plot.position, plot.align, plot.render_density) do img, pos, align, render_density
        halign, valign = align
        x, y = pos
        w, h = round.(Int, size(img) ./ render_density)

        x -= w / 2
        y -= h / 2

        if halign == :left
            x -= w/2
        elseif halign == :center
            x -= 0
        elseif halign == :right
            x -= w
        end

        if valign == :top
            y -= h/2
        elseif valign == :center
            y -= 0
        elseif valign == :bottom
            y -= -h/2
        end

        xr[] = x..x+w
        yr[] = y..y+h
        nothing
    end

    model = map(plot.model, plot.rotation, xr, yr) do model, angle, xr, yr
        x0 = xr.left; x1 = xr.right
        y0 = yr.left; y1 = yr.right
        model *
        Makie.translationmatrix(Vec3{Float32}(0.5(x1+x0), 0.5(y1+y0), 0)) *
        Makie.rotationmatrix_z(angle) *
        Makie.translationmatrix(- Vec3{Float32}(0.5(x1+x0), 0.5(y1+y0), 0))
    end

    image!(plot, xr, yr, img, model=model)
end

function CairoMakie.draw_plot(scene::Scene, screen::CairoMakie.CairoScreen, img::T) where T <: MakieTeX.TeXImg

    bbox = Makie.boundingbox(img)

    ctx = screen.context
    tex = img[1][]
    halign, valign = img.align[]

    x0, y0 = 0.0, 0.0
    w, h = tex.dims

    pos = CairoMakie.project_position(
        scene, img.space[],
        Makie.apply_transform(scene.transformation.transform_func[], img.position[]),
        img.model[]
    )
    scale = img.scale[]
    _w = scale * w; _h = scale * h
    scale_factor = CairoMakie.project_scale(scene, img.space[], Vec2{Float32}(_w, _h), img.model[])

    pos = if halign == :left
        pos .- (scale_factor[1] / 2, 0) .- (0, 0)
    elseif halign == :center
        pos .- (scale_factor[1] / 2, 0)
    elseif halign == :right
        pos .- (scale_factor[1]/2, 0)
    end

    pos = if valign == :top
        pos
    elseif valign == :center
        pos .+ (0, scale_factor[2] / 2)
    elseif valign == :bottom
        pos .+ (0, scale_factor[2])
    end



    Cairo.save(ctx)
    Cairo.translate(
        ctx,
        pos[1],
        pos[2] - (1 + y0/h) * scale_factor[2]
    )

    # Rotated center - normal center

    Cairo.rotate(ctx, -img.rotation[])

    cx = 0.5scale_factor[1] * cos(img.rotation[]) - 0.5scale_factor[2] * sin(img.rotation[]) - 0.5scale_factor[1]
    cy = 0.5scale_factor[1] * sin(img.rotation[]) + 0.5scale_factor[2] * cos(img.rotation[]) - 0.5scale_factor[2]
    Cairo.translate(ctx, cx, cy)

    Cairo.scale(
        ctx,
        scale_factor[1] / w,
        scale_factor[2] / h
    )

    # render to screen

    document = tex.ptr
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid},
        (Ptr{Cvoid}, Cint),
        document, 0 # page 0 is first page
    )
    # Render the page to the surface
    ccall(
        (:poppler_page_render, Poppler_jll.libpoppler_glib),
        Cvoid,
        (Ptr{Cvoid}, Ptr{Cvoid}),
        page, ctx.ptr
    )

    Cairo.restore(ctx)
end
