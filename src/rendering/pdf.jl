# PDF rendering via Poppler + Cairo.

# Lazy handle for `PDF`. Poppler's handle is a refcounted GObject; we hold
# a raw pointer plus dims and only parse on first use. A C_NULL handle on
# entry means "not loaded yet".
function ensure_loaded!(pdf::PDF)
    if pdf.handle[] == C_NULL
        ptr = load_pdf(pdf.bytes)
        pdf.handle[] = ptr
        pdf.dims[] = pdf_get_page_size(ptr, pdf.page)
    end
    return pdf
end

function get_poppler_page(pdf::PDF)::Ptr{Cvoid}
    ensure_loaded!(pdf)
    page = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid}, (Ptr{Cvoid}, Cint), pdf.handle[], pdf.page,
    )
    page == C_NULL && error("Poppler could not read page $(pdf.page) of PDF.")
    return page
end

"""
    rasterize(pdf::PDF; render_density = 1)

Rasterize the selected page to an ARGB32 image at `render_density` pixels
per pt.
"""
function rasterize(pdf::PDF; render_density::Real = 1)
    ensure_loaded!(pdf)
    return page2img(pdf, pdf.page; render_density)
end

"""
    load_pdf(bytes::Vector{UInt8}) -> Ptr{Cvoid}

Parse PDF bytes into a Poppler document handle.
"""
function load_pdf(pdf::Vector{UInt8})::Ptr{Cvoid}
    document = ccall(
        (:poppler_document_new_from_data, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid},
        (Ptr{Cchar}, Csize_t, Cstring, Ptr{Cvoid}),
        pdf, Csize_t(length(pdf)), C_NULL, C_NULL,
    )
    document == C_NULL && error("Poppler could not load the PDF data.")
    return document
end

# Texture rasterization, used by `rasterize_marker_for_gpu` on GPU backends.
function page2img(pdf::PDF, page::Int; render_density::Real = 1)
    ensure_loaded!(pdf)
    return page2img(pdf.handle[], page, pdf.dims[]; render_density)
end

function page2img(document::Ptr{Cvoid}, page::Int, tex_dims::Tuple; render_density::Real = 1)
    page_ptr = ccall(
        (:poppler_document_get_page, Poppler_jll.libpoppler_glib),
        Ptr{Cvoid}, (Ptr{Cvoid}, Cint), document, page,
    )

    w = ceil(Int, tex_dims[1] * render_density)
    h = ceil(Int, tex_dims[2] * render_density)

    img = fill(Colors.ARGB32(0, 0, 0, 0), w, h)
    surf = CairoImageSurface(img)
    ccall(
        (:cairo_surface_set_device_scale, Cairo.libcairo), Cvoid,
        (Ptr{Nothing}, Cdouble, Cdouble),
        surf.ptr, render_density, render_density,
    )

    ctx = Cairo.CairoContext(surf)
    Cairo.set_antialias(ctx, Cairo.ANTIALIAS_BEST)
    Cairo.save(ctx)
    ccall(
        (:poppler_page_render, Poppler_jll.libpoppler_glib),
        Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), page_ptr, ctx.ptr,
    )
    Cairo.restore(ctx)
    Cairo.finish(surf)
    return permutedims(img)
end

firstpage2img(pdf::PDF; kwargs...) = page2img(pdf, 0; kwargs...)
