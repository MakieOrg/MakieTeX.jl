# Integration with Makie's `text` recipe via the AbstractTextPrimitive
# extension hook (added in Makie 0.25). Allows MakieTeX to feed real LaTeX
# directly into `text()`, Axis labels, ticks, titles, etc.
#
# See companion PR: https://github.com/MakieOrg/Makie.jl/pull/5632

"""
    TeXString(s)

A wrapper `AbstractString` that flags content for full-LaTeX rendering via
MakieTeX when passed through `text()`. Unlike `LaTeXString` (which uses
MathTeXEngine for in-process glyph layout), a `TeXString` is compiled with a
real LaTeX engine and embedded into the text plot as a single image primitive.
It Just Works™ everywhere `text()` is used: `text!()` calls, Axis `title`,
`xlabel`, `ylabel`, `xtickformat` returning a `Vector{TeXString}`, etc.
"""
struct TeXString <: AbstractString
    s::String
end
TeXString(s::AbstractString) = TeXString(String(s))
TeXString(l::LaTeXString) = TeXString(String(l))

# Forward the AbstractString interface to the wrapped String.
Base.ncodeunits(t::TeXString) = ncodeunits(t.s)
Base.codeunit(t::TeXString) = codeunit(t.s)
Base.codeunit(t::TeXString, i::Integer) = codeunit(t.s, i)
Base.iterate(t::TeXString) = iterate(t.s)
Base.iterate(t::TeXString, i::Integer) = iterate(t.s, i)
Base.isvalid(t::TeXString, i::Integer) = isvalid(t.s, i)
Base.String(t::TeXString) = t.s
Base.convert(::Type{String}, t::TeXString) = t.s

# A TeXString never counts as whitespace for layout purposes — Axis label
# layout checks `iswhitespace` to decide whether to reserve space for the label.
Makie.iswhitespace(::TeXString) = false

# Scatter centers its marker on the position, then adds `marker_offset`. To
# make `position` correspond to the alignment edge of the marker, shift by
# half the marker size scaled by the alignment fraction.
function _texstring_align_offset(align::Tuple, wh::Makie.Vec2f)
    halign, valign = align
    fhalign = halign === :left ? 0.0f0 :
        halign === :center ? 0.5f0 :
        halign === :right ? 1.0f0 : Float32(halign)
    fvalign = valign === :bottom ? 0.0f0 :
        valign === :center ? 0.5f0 :
        valign === :top ? 1.0f0 : Float32(valign)
    return Makie.Vec2f((0.5f0 - fhalign) * wh[1], (0.5f0 - fvalign) * wh[2])
end

# LaTeX's default base font is 12pt; we scale the rendered PDF's pt dims so
# that fontsize=12 in Makie ≈ 12pt rendered output.
const _TEXSTRING_BASE_PT = 12.0f0

function Makie.convert_text_string!(
        outputs::NamedTuple, input_text::TeXString,
        i, N, fontsize, font, align, rotation, justification,
        lineheight, word_wrap_width, offset, fonts, color, strokecolor, strokewidth
    )

    fs = Float32(Makie.sv_getindex(fontsize, i))
    al = Makie.sv_getindex(align, i)
    rot = convert(Makie.Quaternionf, Makie.sv_getindex(rotation, i))
    off = Makie.Vec3f(Makie.sv_getindex(offset, i))

    # Compile LaTeX → cached PDF → rasterized image. Bypass MakieTeX's
    # `rasterize(::CachedTEX)` because it ignores the `scale` arg for TEX;
    # `page2img` honors `render_density` directly.
    cached = CachedTEX(input_text.s)
    density = max(2, ceil(Int, Float64(fs) / _TEXSTRING_BASE_PT) * 4)
    img = page2img(cached, cached.doc.page; render_density = density)

    dim_pt = Makie.Vec2f(Float32(cached.dims[1]), Float32(cached.dims[2]))
    target_size = dim_pt .* (fs / _TEXSTRING_BASE_PT)
    align_off = _texstring_align_offset(al, target_size)
    marker_offset = Makie.Vec3f(align_off[1], align_off[2], 0) + off

    # `text_blocks` must have one entry per input string. This block has no
    # glyphs — only an image primitive — so we push an empty range.
    curr = length(outputs.glyphindices)
    push!(outputs.text_blocks, (curr + 1):curr)
    push!(
        outputs.glyphcollections, Makie.GlyphCollection(
            UInt64[], Makie.NativeFont[], Makie.Point3f[], Makie.GlyphExtent[],
            Makie.Vec2f[], Makie.Quaternionf[], Makie.RGBAf[], Makie.RGBAf[], Float32[]
        )
    )

    push!(outputs.text_primitives, Makie.ImageTextPrimitive(img, marker_offset, target_size, rot))
    push!(outputs.text_primitive_block_indices, i)
    return
end
