# Reference figures. Each `reftest("name"; backend) do … end` produces a
# figure rendered with the named backend and pixel-diffs it against the
# committed reference image.

# Two-line cross used as a fixed reference point in alignment figures; the
# text under test is anchored to (0, 0) and the lines mark exactly that
# position so we can see how each alignment offsets the glyphs.
function _cross!(ax, x, y; color = :red, length = 0.4)
    lines!(ax, [x - length, x + length], [y, y]; color, linewidth = 1)
    lines!(ax, [x, x], [y - length, y + length]; color, linewidth = 1)
    return
end

# Sample data shared across the axis fixtures so the diff focuses on text.
const _T = range(0, 10; length = 200)
const _Y = exp.(-0.3 .* _T) .* cos.(2π .* _T)

# ---------------------------------------------------------------------------
# Axes where the handler claims every text element (full = true)
# ---------------------------------------------------------------------------

function _axis_full(backend::Symbol, handler_factory)
    reftest("axis_full_$(lowercase(string(nameof(typeof(handler_factory(true))))))";
            backend, size = (500, 400)) do
        Makie.set_theme!(; text_handler = handler_factory(true))
        fig = Makie.Figure()
        ax = Makie.Axis(fig[1, 1];
            title = "Damped oscillation",
            xlabel = "time t (seconds)",
            ylabel = "amplitude A(t)",
        )
        Makie.lines!(ax, _T, _Y; label = "model")
        Makie.axislegend(ax; position = :rt)
        Makie.set_theme!()
        fig
    end
end

# ---------------------------------------------------------------------------
# Axes where individual text elements opt in via L"…" or typst"…"
# ---------------------------------------------------------------------------

function _axis_mixed_latex(backend::Symbol)
    reftest("axis_mixed_latex"; backend, size = (500, 400)) do
        Makie.set_theme!(; text_handler = MakieTeX.LaTeX())
        fig = Makie.Figure()
        ax = Makie.Axis(fig[1, 1];
            title = L"\int_0^\infty e^{-x^2}\, dx = \tfrac{\sqrt{\pi}}{2}",
            xlabel = "time (plain freetype)",
            ylabel = L"A(t) = e^{-\lambda t}\cos(2\pi t)",
        )
        Makie.lines!(ax, _T, _Y)
        Makie.set_theme!()
        fig
    end
end

function _axis_mixed_typst(backend::Symbol)
    reftest("axis_mixed_typst"; backend, size = (500, 400)) do
        Makie.set_theme!(; text_handler = MakieTeX.Typst())
        fig = Makie.Figure()
        ax = Makie.Axis(fig[1, 1];
            title = typst"$ integral_0^infinity e^(-x^2) dif x = sqrt(pi) / 2 $",
            xlabel = "time (plain freetype)",
            ylabel = typst"$ A(t) = e^(-lambda t) cos(2 pi t) $",
        )
        Makie.lines!(ax, _T, _Y)
        Makie.set_theme!()
        fig
    end
end

# ---------------------------------------------------------------------------
# Labels in Boxes — visualize the reported bbox for each handler/input combo.
# ---------------------------------------------------------------------------

function _label_in_box!(layout, row::Int, col::Int, label_args...; label_kw...)
    sub = Makie.GridLayout(layout[row, col]; tellwidth = false, tellheight = false)
    Makie.Label(sub[1, 1], label_args...; label_kw...)
    Makie.Box(sub[1, 1]; color = :transparent, strokecolor = :red, cornerradius = 0)
    return
end

function _bbox_labels(backend::Symbol)
    reftest("bbox_labels"; backend, size = (700, 300)) do
        fig = Makie.Figure()
        # Header row labels (FreeType — plain Strings, FreeType bypass)
        Makie.Label(fig[1, 1], "FreeType"; fontsize = 12, font = :bold)
        Makie.Label(fig[1, 2], "LaTeX"; fontsize = 12, font = :bold)
        Makie.Label(fig[1, 3], "Typst"; fontsize = 12, font = :bold)

        gl = Makie.GridLayout(fig[2, 1:3])

        # FreeType: no handler set.
        _label_in_box!(gl, 1, 1, "Damped oscillation"; fontsize = 14)
        _label_in_box!(gl, 2, 1, "Hgyp ABC"; fontsize = 14)

        # LaTeX (load handler just for this column).
        Makie.set_theme!(; text_handler = MakieTeX.LaTeX(full = true))
        _label_in_box!(gl, 1, 2, "Damped oscillation"; fontsize = 14)
        _label_in_box!(gl, 2, 2, L"\sqrt{a^2 + b^2}"; fontsize = 14)
        Makie.set_theme!()

        Makie.set_theme!(; text_handler = MakieTeX.Typst(full = true))
        _label_in_box!(gl, 1, 3, "Damped oscillation"; fontsize = 14)
        _label_in_box!(gl, 2, 3, typst"$ sqrt(a^2 + b^2) $"; fontsize = 14)
        Makie.set_theme!()
        fig
    end
end

# ---------------------------------------------------------------------------
# Alignment grid — every halign × valign combo with a cross at the anchor.
# ---------------------------------------------------------------------------

function _alignment_grid(name::String, backend::Symbol, handler, content)
    reftest(name; backend, size = (560, 420)) do
        handler !== nothing && Makie.set_theme!(; text_handler = handler)
        fig = Makie.Figure()
        halign = [:left, :center, :right]
        valign = [:top, :center, :baseline, :bottom]

        for (i, va) in enumerate(valign), (j, ha) in enumerate(halign)
            ax = Makie.Axis(fig[i, j];
                title = "$ha, $va",
                titlesize = 9,
                xticksvisible = false, yticksvisible = false,
                xticklabelsvisible = false, yticklabelsvisible = false,
                limits = (-1.0, 1.0, -1.0, 1.0),
                aspect = Makie.DataAspect(),
            )
            _cross!(ax, 0.0, 0.0)
            Makie.text!(ax, 0.0, 0.0;
                text = content,
                align = (ha, va),
                fontsize = 22,
            )
        end
        Makie.set_theme!()
        fig
    end
end

# ---------------------------------------------------------------------------
# Backend-parameterized test entry points
# ---------------------------------------------------------------------------

function run_reftests(backend::Symbol)
    _axis_full(backend, full -> MakieTeX.LaTeX(; full))
    _axis_full(backend, full -> MakieTeX.Typst(; full))
    _axis_mixed_latex(backend)
    _axis_mixed_typst(backend)
    _bbox_labels(backend)
    _alignment_grid("alignment_freetype", backend, nothing, "Hgyp")
    _alignment_grid("alignment_latex", backend, MakieTeX.LaTeX(), L"H_g^{y_p}")
    _alignment_grid("alignment_typst", backend, MakieTeX.Typst(), typst"$ H_g^(y_p) $")
    return
end
