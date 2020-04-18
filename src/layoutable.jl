mutable struct LTeX <: MakieLayout.LObject
    parent::Scene
    layoutobservables::MakieLayout.LayoutObservables
    plot::TeXImg
    attributes::Attributes
end

function default_attributes(::Type{LTeX}, scene)
    Attributes(
        tex = raw"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}",
        visible = true,
        padding = (0f0, 0f0, 0f0, 0f0),
        height = Auto(),
        width = Auto(),
        alignmode = Inside(),
        valign = :center,
        halign = :left,
    )
end

function LTeX(parent::Scene, tex; kwargs...)
    LTeX(parent; tex = tex, kwargs...)
end

function LTeX(parent::Scene; bbox = nothing, kwargs...)
    attrs = merge!(Attributes(kwargs), default_attributes(LTeX, parent))

    @extract attrs (tex, visible, padding, halign, valign)

    layoutobservables = LayoutObservables(LTeX, attrs.width, attrs.height, halign, valign, attrs.alignmode; suggestedbbox = bbox)

    textpos = Node(Point2f0(0, 0))

    cached_tex = @lift CachedTeX($tex)

    wh = @lift ($cached_tex.raw_dims.width, $cached_tex.raw_dims.height)

    t = teximg!(parent, textpos, cached_tex; visible = visible, raw = true, align = @lift ($halign, $valign))[end]

    onany(cached_tex, padding, ) do cached_tex, padding
        autowidth = cached_tex.raw_dims.width + padding[1] + padding[2]
        autoheight = cached_tex.raw_dims.height + padding[3] + padding[4]
        layoutobservables.autosize[] = (autowidth, autoheight)
    end

    onany(layoutobservables.computedbbox, padding, halign, valign) do bbox, padding, halign, valign

        tw = cached_tex[].raw_dims.width
        th = cached_tex[].raw_dims.height

        box = bbox.origin[1]
        boy = bbox.origin[2]

        # this is also part of the hack to improve left alignment until
        # boundingboxes are perfect
        tx = box + padding[1]
        ty = boy + padding[3]

        textpos[] = Point2f0(tx, ty)
    end


    # trigger first update, otherwise bounds are wrong somehow
    tex[] = tex[]
    # trigger bbox
    layoutobservables.suggestedbbox[] = layoutobservables.suggestedbbox[]

    lt = LTeX(parent, layoutobservables, t, attrs)

    lt
end

defaultlayout(lt::LTeX) = ProtrusionLayout(lt)

function align_to_bbox!(lt::LTeX, bbox)
    lt.layoutobservables.suggestedbbox[] = bbox
end

computedsizenode(lt::LTeX) = lt.layoutobservables.computedsize
protrusionnode(lt::LTeX) = lt.layoutobservables.protrusions


function Base.getproperty(lt::LTeX, s::Symbol)
    if s in fieldnames(LTeX)
        getfield(lt, s)
    else
        lt.attributes[s]
    end
end

function Base.setproperty!(lt::LTeX, s::Symbol, value)
    if s in fieldnames(LTeX)
        setfield!(lt, s, value)
    else
        lt.attributes[s][] = value
    end
end

function Base.propertynames(lt::LTeX)
    [fieldnames(LTeX)..., keys(lt.attributes)...]
end

function Base.delete!(lt::LTeX)

    disconnect_layoutnodes!(lt.layoutobservables.gridcontent)
    GridLayoutBase.remove_from_gridlayout!(lt.layoutobservables.gridcontent)
    empty!(lt.layoutobservables.suggestedbbox.listeners)
    empty!(lt.layoutobservables.computedbbox.listeners)
    empty!(lt.layoutobservables.computedsize.listeners)
    empty!(lt.layoutobservables.autosize.listeners)
    empty!(lt.layoutobservables.protrusions.listeners)

    # remove the plot object from the scene
    delete!(lt.parent, lt.plot)
end



# LLegend integration
# function MakieLayout.layoutable_textlike(scene, label::LaTeXString, textsize, font, color, halign, valign)
#     return LTeX(scene,
#         tex = label,
#         halign = halign,
#         valign = valign
#     )
# end
#
# function MakieLayout.layoutable_textlike(scene, label::TeXDocument, textsize, font, color, halign, valign)
#     return LTeX(scene,
#         tex = label,
#         halign = halign,
#         valign = valign
#     )
# end
