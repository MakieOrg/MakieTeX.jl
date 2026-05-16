module MakieTeXGLMakieExt

# Rasterize cached LaTeX/PDF documents into a Matrix{ARGB32} so GLMakie's
# scatter marker pipeline can upload them as a GPU texture. CairoMakie has
# its own native vector dispatch (see MakieTeXCairoMakieExt) and does NOT
# go through this hook, so this extension only affects GL/WGL-style
# backends and doesn't compromise CairoMakie's vector quality.

using GLMakie, MakieTeX
using Makie

# Heuristic for rasterization density. `s` is per-marker pixel-size in
# markerspace (Vec2f); take its longest axis and scale by a factor so that
# a 30pt fontsize → ~density 4 (good visual fidelity without huge textures).
_density_for_size(s) = max(2, ceil(Int, maximum(s) / 8))

function Makie.rasterize_marker_for_gpu(doc::MakieTeX.AbstractCachedDocument, scale)
    s = scale isa AbstractVector ? first(scale) : scale
    return _rasterize_doc(doc, _density_for_size(s))
end

function Makie.rasterize_marker_for_gpu(docs::AbstractVector{<:MakieTeX.AbstractCachedDocument}, scale)
    # Per-marker scale if `scale` is a Vector, otherwise broadcast the
    # scalar.
    sizes = scale isa AbstractVector ? scale : fill(scale, length(docs))
    return [_rasterize_doc(d, _density_for_size(sz)) for (d, sz) in zip(docs, sizes)]
end

# `MakieTeX.rasterize(::CachedTEX/CachedTypst, _)` currently ignores its
# `scale` arg; `page2img(…; render_density)` honors it. Route through that
# uniformly so fontsize controls bitmap resolution.
function _rasterize_doc(doc::MakieTeX.AbstractCachedDocument, density::Int)
    return MakieTeX.page2img(doc, doc.doc isa Nothing ? 0 : doc.doc.page;
        render_density = density)
end

end
