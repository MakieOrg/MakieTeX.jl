# Reference figures. Each builder returns a `Makie.Figure`; `run_reftests`
# renders it with the chosen backend and pixel-diffs via `@test_pixelmatch`.

function cross!(ax, x, y; color = :red, length = 0.4)
    lines!(ax, [x - length, x + length], [y, y]; color, linewidth = 1)
    lines!(ax, [x, x], [y - length, y + length]; color, linewidth = 1)
    return
end

const T = range(0, 10; length = 200)
const Y = exp.(-0.3 .* T) .* cos.(2π .* T)

function axis_full(handler)
    Makie.with_theme(; text_handler = handler) do
        fig = Makie.Figure(size = (500, 400))
        ax = Makie.Axis(fig[1, 1];
            title = "Damped oscillation",
            xlabel = "time t (seconds)",
            ylabel = "amplitude A(t)",
        )
        Makie.lines!(ax, T, Y; label = "model")
        Makie.axislegend(ax; position = :rt)
        fig
    end
end

function axis_mixed_latex()
    Makie.with_theme(; text_handler = MakieTeX.LaTeX()) do
        fig = Makie.Figure(size = (500, 400))
        ax = Makie.Axis(fig[1, 1];
            title = L"\int_0^\infty e^{-x^2}\, dx = \tfrac{\sqrt{\pi}}{2}",
            xlabel = "time (plain freetype)",
            ylabel = L"A(t) = e^{-\lambda t}\cos(2\pi t)",
        )
        Makie.lines!(ax, T, Y)
        fig
    end
end

function axis_mixed_typst()
    Makie.with_theme(; text_handler = MakieTeX.Typst()) do
        fig = Makie.Figure(size = (500, 400))
        ax = Makie.Axis(fig[1, 1];
            # `$…$` with no surrounding spaces is inline math; the spaced
            # form is display math which inflates the rotated y-label.
            title = typst"$integral_0^infinity e^(-x^2) dif x = sqrt(pi) / 2$",
            xlabel = "time (plain freetype)",
            ylabel = typst"$A(t) = e^(-lambda t) cos(2 pi t)$",
        )
        Makie.lines!(ax, T, Y)
        fig
    end
end

function label_in_box!(layout, row::Int, col::Int, label_args...; label_kw...)
    Makie.Label(layout[row, col], label_args...; label_kw...)
    Makie.Box(layout[row, col]; color = :transparent, strokecolor = :red, cornerradius = 0)
    return
end

function bbox_labels(handler, labels::Vector)
    theme = handler === nothing ? Makie.Theme() : Makie.Theme(text_handler = handler)
    Makie.with_theme(theme) do
        fig = Makie.Figure(size = (400, 250))
        for (row, content) in enumerate(labels)
            label_in_box!(fig.layout, row, 1, content; fontsize = 14)
        end
        fig
    end
end

# Same content/fontsize through each handler so any visual size difference
# is scaling/metrics rather than font shape.
function font_scaling()
    tgh_dir = joinpath(Makie.assetpath(), "fonts")
    tgh_file = joinpath(tgh_dir, "TeXGyreHerosMakie-Regular.otf")
    content = "Hgyp 0123"
    fs = 28

    # lualatex's CFF parser refuses TGHM (deprecated `dotsection`
    # operator); tectonic handles it fine.
    latex_handler = MakieTeX.LaTeX(full = true, engine = `tectonic`, preamble = """
        \\usepackage{xcolor}
        \\usepackage{fontspec}
        \\setmainfont{TeXGyreHerosMakie-Regular.otf}[Path=$(tgh_dir)/]
    """)

    # All four TGHM variants share OS/2 metadata (weight 500,
    # fsSelection=REGULAR), so Typst can't pick a specific variant from
    # tgh_dir and lands on Bold. Restrict it to a dir with only Regular.
    typst_font_dir = mktempdir()
    cp(tgh_file, joinpath(typst_font_dir, basename(tgh_file)); force = true)
    typst_handler = MakieTeX.Typst(
        full = true, font = "TeX Gyre Heros Makie", font_paths = [typst_font_dir],
    )

    fig = Makie.Figure(size = (500, 240))
    ax = Makie.Axis(fig[1, 1];
        xticksvisible = false, yticksvisible = false,
        xticklabelsvisible = false, yticklabelsvisible = false,
        xgridvisible = false, ygridvisible = false,
        limits = (0, 1, 0, 3.4),
    )

    rows = [
        (3.0, "FreeType", (; font = tgh_file)),
        (2.0, "LaTeX/TGH", (; text_handler = latex_handler)),
        (1.0, "Typst/TGH", (; text_handler = typst_handler)),
    ]
    for (y, label, kw) in rows
        Makie.text!(ax, 0.05, y; text = content, fontsize = fs,
            align = (:left, :baseline), kw...)
        Makie.text!(ax, 0.7, y; text = label, fontsize = 12, font = tgh_file,
            align = (:left, :baseline), color = :gray40)
    end

    Makie.hlines!(ax, [1.0, 2.0, 3.0]; color = (:red, 0.3), linewidth = 0.5)
    fig
end

# Every halign × valign combo with a cross at the anchor. Single shared
# axis instead of per-cell axes — those clipped rotated math markers.
function alignment_grid(handler, content)
    theme = handler === nothing ? Makie.Theme() : Makie.Theme(text_handler = handler)
    Makie.with_theme(theme) do
        fig = Makie.Figure(size = (560, 420))
        halign = [:left, :center, :right]
        valign = [:top, :center, :baseline, :bottom]

        xs = Float64[1, 2, 3]
        ys = Float64[4, 3, 2, 1]
        ax = Makie.Axis(fig[1, 1];
            xticksvisible = false, yticksvisible = false,
            xticklabelsvisible = false, yticklabelsvisible = false,
            xgridvisible = false, ygridvisible = false,
            limits = (0.5, 3.5, 0.4, 4.5),
            aspect = Makie.DataAspect(),
        )

        for (i, va) in enumerate(valign), (j, ha) in enumerate(halign)
            x, y = xs[j], ys[i]
            cross!(ax, x, y; length = 0.25)
            Makie.text!(ax, x, y; text = content, align = (ha, va), fontsize = 16)
            Makie.text!(ax, x, y + 0.4; text = "$ha, $va",
                align = (:center, :center), fontsize = 8, color = :gray40)
        end
        fig
    end
end

const SAMPLE_SVG = """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">
  <circle cx="20" cy="20" r="18" fill="#ff8800" stroke="#003366" stroke-width="3"/>
  <text x="20" y="26" font-family="sans-serif" font-size="16" fill="white" text-anchor="middle">S</text>
</svg>"""

# Square page with a circle inscribed — the rendered marker has known 1:1
# aspect ratio, so any squish shows up immediately.
function sample_pdf_bytes()
    doc = """
    #set page(width: 40pt, height: 40pt, margin: 0pt, fill: white)
    #place(center + horizon, circle(radius: 18pt, stroke: 3pt + rgb("#003366"), fill: rgb("#ff8800")))
    #place(center + horizon, text(size: 14pt, fill: white, weight: "bold")[PDF])
    """
    return mktempdir() do dir
        cd(dir) do
            write("doc.typ", doc)
            redirect_stdio(stdout = devnull, stderr = devnull) do
                run(typst`compile doc.typ doc.pdf`)
            end
            read("doc.pdf")
        end
    end
end

function asset_markers(marker)
    fig = Makie.Figure(size = (320, 220))
    ax = Makie.Axis(fig[1, 1]; limits = (0, 6, 0, 1))
    Makie.scatter!(ax, 1:5, [0.5, 0.7, 0.3, 0.6, 0.4]; marker, markersize = 50)
    fig
end

function compare(name::String, fig, backend::Symbol)
    bemod = backend === :CairoMakie ? CairoMakie : GLMakie
    subdir = lowercase(string(backend))
    img = Makie.colorbuffer(fig; backend = bemod, px_per_unit = 2)
    @test_pixelmatch "reference_images/$subdir/$name" img
end

function run_reftests(backend::Symbol)
    # Skip latex full-axis: every tick label would compile through LaTeX,
    # which is slow; bbox/alignment tests already cover latex bbox.
    compare("axis_full_typst", axis_full(MakieTeX.Typst(full = true)), backend)
    compare("axis_mixed_typst", axis_mixed_typst(), backend)
    compare("font_scaling", font_scaling(), backend)
    compare("bbox_labels_freetype", bbox_labels(nothing, ["Damped oscillation", "Hgyp ABC"]), backend)
    compare("bbox_labels_latex", bbox_labels(MakieTeX.LaTeX(full = true), ["Damped oscillation", L"\sqrt{a^2 + b^2}"]), backend)
    compare("bbox_labels_typst", bbox_labels(MakieTeX.Typst(full = true), ["Damped oscillation", typst"$ sqrt(a^2 + b^2) $"]), backend)
    compare("alignment_freetype", alignment_grid(nothing, "Hgyp"), backend)
    compare("alignment_latex", alignment_grid(MakieTeX.LaTeX(full = true), "Hgyp"), backend)
    compare("alignment_typst", alignment_grid(MakieTeX.Typst(full = true), "Hgyp"), backend)
    compare("marker_svg", asset_markers(MakieTeX.SVG(Vector{UInt8}(SAMPLE_SVG))), backend)
    compare("marker_pdf", asset_markers(MakieTeX.PDF(sample_pdf_bytes())), backend)
    return
end
