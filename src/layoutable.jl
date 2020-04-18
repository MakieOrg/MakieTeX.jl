mutable struct LTeX <: MakieLayout.LObject
    parent::Scene
    layoutobservables::MakieLayout.LayoutObservables
    cached_tex::CachedTeX
    plot::TeXImg
    attributes::Attributes
end

function LTeX(parent::Scene, tex; kwargs...)
    LTeX(parent; tex = tex, kwargs...)
end

function LTeX(parent::Scene; bbox = nothing, kwargs...)
    attrs = merge!(Attributes(kwargs), default_attributes(LTeX, parent))

    @extract attrs (tex, visible, padding)

    layoutobservables = LayoutObservables(LTeX, attrs.width, attrs.height,
        halign, valign, attrs.alignmode; suggestedbbox = bbox)

    textpos = Node(Point2f0(0, 0))

    cached_tex = @lift CachedTeX($tex)

    t = teximg!(parent, textpos, tex; visible = visible, raw = true)[end]

    onany(text, padding) do text, padding
        autowidth = cached_tex.dims.width + padding[1] + padding[2]
        autoheight = cached_tex.dims.height + padding[3] + padding[4]
        layoutobservables.autosize[] = (autowidth, autoheight)
    end

    onany(layoutobservables.computedbbox, padding) do bbox, padding

        tw = cached_tex.dims.width
        th = cached_tex.dims.height

        box = bbox.origin[1]
        boy = bbox.origin[2]

        # this is also part of the hack to improve left alignment until
        # boundingboxes are perfect
        tx = box + padding[1]
        ty = boy + padding[3] + 0.5 * th

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
