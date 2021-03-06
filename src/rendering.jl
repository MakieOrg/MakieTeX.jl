const DVISVGM_PATH = Ref(readchomp(`which dvisvgm`))

function compile_latex(
        document::AbstractString;
        tex_engine = `lualatex`,
        options = `-halt-on-error`,
        format = "dvi"
    )
    return mktempdir() do dir

        # dir=mktempdir()
        # Begin by compiling the latex in a temp directory
        # Unfortunately for us, Luatex does not like to compile
        # straight to stdout; it really wants a filename.
        # We make a temporary directory for it to output to.
        latex = open(`$tex_engine $options -output-directory=$dir -output-format=$format -jobname=temp`, "r+")
        print(latex, document) # print the TeX document to stdin
        close(latex.in)      # close the file descriptor to let LaTeX know we're done
        suc = success(latex)
        dircontents = joinpath.(dir, readdir(dir))

        !suc && (println(read(joinpath(dir, "temp.log"), String)))

        # We want to keep file writes to a minimum.  Everything should stay in memory.
        # Therefore, we exit the directory at this point, so that all auxiliary files
        # can be deleted.
        return read(joinpath(dir, "temp.$format"))

    end
end

latex2dvi(args...; kwargs...) = compile_latex(args...; format = "dvi", kwargs...)
latex2pdf(args...; kwargs...) = compile_latex(args...; format = "pdf", kwargs...)

function dvi2svg(
        dvi::Vector{UInt8};
        bbox = .2, # minimal bounding box
        options = ``
    )
    # dvisvgm will allow us to convert the DVI file into an SVG which
    # can be rendered by Rsvg.  In this case, we are able to provide
    # dvisvgm a DVI file from stdin, and receive a SVG string from
    # stdout.  This greatly simplifies the pipeline, and anyone with
    # a working TeX installation should have these utilities available.
    dvisvgm = open(`$(DVISVGM_PATH[]) --bbox=$bbox $options --no-fonts --stdin --stdout`, "r+")

    write(dvisvgm, dvi)

    close(dvisvgm.in)

    return read(dvisvgm.out, String) # read the SVG in as a String
end

function pdf2svg(pdf::Vector{UInt8})
    pdftocairo = open(`pdftocairo -svg - -`, "r+")

    write(pdftocairo, pdf)

    close(pdftocairo.in)

    return read(pdftocairo.out, String)
end

# function dvi2png(dvi::Vector{UInt8}; dpi = 72.0, libgs = nothing)
#
#     # dvisvgm will allow us to convert the DVI file into an SVG which
#     # can be rendered by Rsvg.  In this case, we are able to provide
#     # dvisvgm a DVI file from stdin, and receive a SVG string from
#     # stdout.  This greatly simplifies the pipeline, and anyone with
#     # a working TeX installation should have these utilities available.
#     dvipng = open(`dvipng --bbox=$bbox $options --no-fonts  --stdin --stdout `, "r+")
#
#     write(dvipng, dvi)
#
#     close(dvipng.in)
#
#     return read(dvipng.out, String) # read the SVG in as a String
# end

function svg2img(svg::String, dpi = 72.0)

    # First, we instantiate an Rsvg handle, which holds a parsed representation of
    # the SVG.  Then, we set its DPI to the provided DPI (usually, 300 is good).
    handle = Rsvg.handle_new_from_data(svg)
    Rsvg.handle_set_dpi(handle, dpi)

    # We can find the final dimensions (in pixel units) of the Rsvg image.
    # Then, it's possible to store the image in a native Julia array,
    # which simplifies the process of rendering.
    d = Rsvg.handle_get_dimensions(handle)

    # NOTE
    # I did not check if this needs to be filled, but rsvg2img needs it...
    w, h = d.width, d.height
    img = fill(Colors.ARGB32(1,1,1,0), w, h)

    # Cairo allows you to use a Matrix of ARGB32, which simplifies rendering.
    cs = Cairo.CairoImageSurface(img)
    c = Cairo.CairoContext(cs)

    # Render the parsed SVG to a Cairo context
    Rsvg.handle_render_cairo(c, handle)

    # The image is rendered transposed, so we need to flip it.
    return rotr90(permutedims(img))
end

function rsvg2img(handle::Rsvg.RsvgHandle, dpi = 72.0)
    Rsvg.handle_set_dpi(handle, dpi)

    # We can find the final dimensions (in pixel units) of the Rsvg image.
    # Then, it's possible to store the image in a native Julia array,
    # which simplifies the process of rendering.
    d = Rsvg.handle_get_dimensions(handle)
    
    # Cairo does not draw "empty" pixels, so we need to fill here
    w, h = d.width, d.height
    img = fill(Colors.ARGB32(1,1,1,0), w, h)

    # Cairo allows you to use a Matrix of ARGB32, which simplifies rendering.
    cs = Cairo.CairoImageSurface(img)
    c = Cairo.CairoContext(cs)

    # Render the parsed SVG to a Cairo context
    Rsvg.handle_render_cairo(c, handle)

    # The image is rendered transposed, so we need to flip it.
    return rotr90(permutedims(img))
end

function svg2rsvg(svg::String, dpi = 72.0)
    handle = Rsvg.handle_new_from_data(svg)
    Rsvg.handle_set_dpi(handle, dpi)
    return handle
end

function rsvg2recordsurf(handle::Rsvg.RsvgHandle)
    surf = Cairo.CairoRecordingSurface()
    ctx  = Cairo.CairoContext(surf)
    Rsvg.handle_render_cairo(ctx, handle)
    return (surf, ctx)
end

function render_surface(ctx::CairoContext, surf)
    Cairo.save(ctx)

    Cairo.set_source(ctx, surf, 0.0, 0.0)

    Cairo.paint(ctx)

    Cairo.restore(ctx)
    return
end
