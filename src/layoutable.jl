MakieLayout.@Layoutable LTeX

function MakieLayout.default_attributes(::Type{LTeX}, scene)
    Attributes(
        tex = raw"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}",
        visible = true,
        padding = (0f0, 0f0, 0f0, 0f0),
        height = Auto(),
        width = Auto(),
        alignmode = Inside(),
        valign = :center,
        halign = :center,
        tellwidth = true,
        tellheight = true,
        dpi = 72.0,
        textsize = 12,
        rotation = 0
    )
end

function MakieLayout.layoutable(::Type{LTeX}, fig_or_scene, tex; kwargs...)
    MakieLayout.layoutable(LTeX, fig_or_scene; tex = tex, kwargs...)
end

function MakieLayout.layoutable(::Type{LTeX}, fig_or_scene; bbox = nothing, kwargs...)
    # this is more or less copied from MakieLayout.Label
    topscene = MakieLayout.get_topscene(fig_or_scene)
    default_attrs = MakieLayout.default_attributes(LTeX, topscene).attributes
    theme_attrs = MakieLayout.subtheme(topscene, :LTeX)
    attrs = MakieLayout.merge!(MakieLayout.merge!(Attributes(kwargs), theme_attrs), Attributes(default_attrs))

    # @extract attrs (tex, textsize, font, color, visible, halign, valign,
    #     rotation, padding)
    @extract attrs (tex, dpi, textsize, visible, padding, halign, valign, rotation)


    layoutobservables = LayoutObservables{LTeX}(
        attrs.width, attrs.height, attrs.tellwidth, attrs.tellheight,
        halign, valign, attrs.alignmode; suggestedbbox = bbox
    )

    # This is Point3f0 in Label
    textpos = Node(Point3f0(0))

    cached_tex = @lift CachedTeX($tex, $dpi)

    # this is just a hack until boundingboxes in abstractplotting are perfect
    alignnode = lift(halign, rotation) do h, rot
        # left align the text if it's not rotated and left aligned
        if rot == 0 && (h == :left || h == 0.0)
            (:left, :center)
        else
            (:center, :center)
        end
    end

    t = teximg!(
        topscene, cached_tex; position = textpos, visible = visible, raw = true,
        textsize = textsize, dpi = dpi, align = alignnode, rotation = rotation
    )

    textbb = Ref(BBox(0, 1, 0, 1))

    # Label
    onany(cached_tex, textsize, rotation, padding) do _, textsize, rotation, padding
        # rotation is applied via a model matrix which isn't used in the bbox calculation
        # so we need to deal with it here
        bb = boundingbox(t)
        R = Makie.Mat3f0(
             cos(rotation), sin(rotation), 0,
            -sin(rotation), cos(rotation), 0,
            0, 0, 1
        )
        points = map(p -> R * p, unique(Makie.coordinates(bb)))
        new_bb = Makie.xyz_boundingbox(identity, points)
        textbb[] = FRect2D(new_bb)
        # textbb[] = FRect2D(boundingbox(t))
        autowidth  = Makie.width(textbb[]) + padding[1] + padding[2]
        autoheight = Makie.height(textbb[]) + padding[3] + padding[4]
        layoutobservables.autosize[] = (autowidth, autoheight)
    end

    onany(layoutobservables.computedbbox, padding) do bbox, padding
        tw = Makie.width(textbb[])
        th = Makie.height(textbb[])
        
        box = bbox.origin[1]
        boy = bbox.origin[2]

        # this is also part of the hack to improve left alignment until
        # boundingboxes are perfect
        tx = if rotation[] == 0 && (halign[] == :left || halign[] == 0.0)
            box + padding[1]
        else
            box + padding[1] + 0.5 * tw
        end
        ty = boy + padding[3] + 0.5 * th

        textpos[] = Point3f0(tx, ty, 0)
    end

    # trigger first update, otherwise bounds are wrong somehow
    padding[] = padding[]
    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    lt = LTeX(fig_or_scene, layoutobservables, attrs, Dict(:tex => t))

    lt
end