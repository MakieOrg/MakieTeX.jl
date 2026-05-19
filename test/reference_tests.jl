# Reference figures. Each builder returns a `Makie.Figure`; `run_reftests`
# renders it with the chosen backend and pixel-diffs via `@test_pixelmatch`.

function cross!(ax, x, y; color = :red, length = 0.4)
    lines!(ax, [x - length, x + length], [y, y]; color, linewidth = 1)
    lines!(ax, [x, x], [y - length, y + length]; color, linewidth = 1)
    return
end

const T = range(0, 10; length = 200)
const Y = exp.(-0.3 .* T) .* cos.(2π .* T)

# Reftest handlers all use TeX Gyre Heros Makie (from Makie's bundled
# assets) so glyph shapes are identical across OSes — important because
# CI runs on Linux/macOS/Windows and a default LaTeX or Typst font would
# differ per platform.
const TGH_FILE = joinpath(Makie.assetpath(), "fonts", "TeXGyreHerosMakie-Regular.otf")
const TGH_TYPST_FONT_DIR = Ref{String}("")

# Typst can't distinguish the four bundled TGHM variants (they share OS/2
# metadata), so point its font search at a scratch dir holding only the
# Regular file.
function tgh_typst_font_dir()
    isempty(TGH_TYPST_FONT_DIR[]) || return TGH_TYPST_FONT_DIR[]
    dir = mktempdir()
    cp(TGH_FILE, joinpath(dir, basename(TGH_FILE)); force = true)
    TGH_TYPST_FONT_DIR[] = dir
    return dir
end

# `tectonic` because lualatex's CFF parser chokes on TGHM's deprecated
# `dotsection` op; `--keep-logs` is needed for baseline depth on the
# extension side (already handled by the extension wrapper).
tgh_latex(; full::Bool = false) = MakieTeX.LaTeX(; full,
    engine = `tectonic`,
    preamble = """
        \\usepackage{xcolor}
        \\usepackage{fontspec}
        \\setmainfont{TeXGyreHerosMakie-Regular.otf}[Path=$(dirname(TGH_FILE))/]
    """)

tgh_typst(; full::Bool = false) = MakieTeX.Typst(; full,
    font = "TeX Gyre Heros Makie",
    font_paths = [tgh_typst_font_dir()],
)

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
    Makie.with_theme(; text_handler = tgh_latex()) do
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
    Makie.with_theme(; text_handler = tgh_typst()) do
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
    content = "Hgyp 0123"
    fs = 28
    latex_handler = tgh_latex(; full = true)
    typst_handler = tgh_typst(; full = true)

    fig = Makie.Figure(size = (500, 240))
    ax = Makie.Axis(fig[1, 1];
        xticksvisible = false, yticksvisible = false,
        xticklabelsvisible = false, yticklabelsvisible = false,
        xgridvisible = false, ygridvisible = false,
        limits = (0, 1, 0, 3.4),
    )

    rows = [
        (3.0, "FreeType", (; font = TGH_FILE)),
        (2.0, "LaTeX/TGH", (; text_handler = latex_handler)),
        (1.0, "Typst/TGH", (; text_handler = typst_handler)),
    ]
    for (y, label, kw) in rows
        Makie.text!(ax, 0.05, y; text = content, fontsize = fs,
            align = (:left, :baseline), kw...)
        Makie.text!(ax, 0.7, y; text = label, fontsize = 12, font = TGH_FILE,
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

# Square page with a circle + label, generated via Typst so glyphs are
# baked into the output (as PDF text + cmap or SVG <symbol>/<use> paths
# with no font lookup at render time). Using TeX Gyre Heros Makie from
# Makie's bundled assets keeps fonts identical across OSes — important
# for CI reftests. The TGHM variants share OS/2 metadata so Typst can't
# pick a specific weight from `tgh_dir`; restrict it to a scratch dir
# with only the Regular file. `fill: none` on the page keeps the corners
# transparent against non-white backgrounds.
const _SAMPLE_DOC_TYPST = """
#set page(width: 40pt, height: 40pt, margin: 0pt, fill: none)
#set text(font: "TeX Gyre Heros Makie", weight: "bold", fill: white)
#place(center + horizon, circle(radius: 18pt, stroke: 3pt + rgb("#003366"), fill: rgb("#ff8800")))
#place(center + horizon, text(size: %SIZE%pt)[%LABEL%])
"""

function _compile_sample(format::AbstractString, size::Real, label::AbstractString)
    tgh_dir = joinpath(Makie.assetpath(), "fonts")
    font_dir = mktempdir()
    cp(joinpath(tgh_dir, "TeXGyreHerosMakie-Regular.otf"),
        joinpath(font_dir, basename("TeXGyreHerosMakie-Regular.otf")); force = true)
    doc = replace(_SAMPLE_DOC_TYPST, "%SIZE%" => string(size), "%LABEL%" => label)
    out_name = "doc." * format
    return mktempdir() do dir
        cd(dir) do
            write("doc.typ", doc)
            redirect_stdio(stdout = devnull, stderr = devnull) do
                run(addenv(TypstCommand(["compile", "--format", format, "doc.typ", out_name]),
                    "TYPST_FONT_PATHS" => font_dir))
            end
            read(out_name)
        end
    end
end

sample_pdf_bytes() = _compile_sample("pdf", 14, "PDF")
sample_svg_bytes() = _compile_sample("svg", 11, "SVG")

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
    compare("axis_full_typst", axis_full(tgh_typst(; full = true)), backend)
    compare("axis_mixed_typst", axis_mixed_typst(), backend)
    compare("font_scaling", font_scaling(), backend)
    compare("bbox_labels_freetype", bbox_labels(nothing, ["Damped oscillation", "Hgyp ABC"]), backend)
    compare("bbox_labels_latex", bbox_labels(tgh_latex(; full = true), ["Damped oscillation", L"\sqrt{a^2 + b^2}"]), backend)
    compare("bbox_labels_typst", bbox_labels(tgh_typst(; full = true), ["Damped oscillation", typst"$ sqrt(a^2 + b^2) $"]), backend)
    compare("alignment_freetype", alignment_grid(nothing, "Hgyp"), backend)
    compare("alignment_latex", alignment_grid(tgh_latex(; full = true), "Hgyp"), backend)
    compare("alignment_typst", alignment_grid(tgh_typst(; full = true), "Hgyp"), backend)
    compare("marker_svg", asset_markers(MakieTeX.SVG(sample_svg_bytes())), backend)
    compare("marker_pdf", asset_markers(MakieTeX.PDF(sample_pdf_bytes())), backend)
    return
end
