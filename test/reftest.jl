# Reference-image test harness. Adapted from AlgebraOfGraphics's
# `reference_tests_utils.jl`. Each `reftest(name; backend) do … end` renders
# a figure with the given Makie backend, saves it under
# `test/reference_images/<backend>/<name> rec.png`, and pixel-diffs against
# `<name> ref.png`. Set `ENV["UPDATE_REFIMAGES"] = "true"` to overwrite the
# reference image in interactive mode.

using Test
using PixelMatch, PNGFiles
using Base64

const REFTEST_ROOT = joinpath(@__DIR__, "reference_images")

backend_subdir(::Type) = error("Unknown backend type")
backend_subdir(::Val{:CairoMakie}) = "cairomakie"
backend_subdir(::Val{:GLMakie}) = "glmakie"

function reftest(
        f::Function, name::String;
        backend::Symbol,
        size = (400, 400),
        update::Bool = get(ENV, "UPDATE_REFIMAGES", "false") == "true",
    )
    bemod = backend === :CairoMakie ? CairoMakie : GLMakie
    fig = Makie.with_theme(f; size)
    dir = joinpath(REFTEST_ROOT, backend_subdir(Val(backend)))
    mkpath(dir)
    ref_path = joinpath(dir, "$name ref.png")
    rec_path = joinpath(dir, "$name rec.png")
    diff_path = joinpath(dir, "$name diff.png")

    Makie.save(rec_path, fig; backend = bemod, px_per_unit = 1)

    @testset "$name [$backend]" begin
        if !isfile(ref_path)
            if isinteractive()
                @info "Creating missing reference image: $ref_path"
                cp(rec_path, ref_path; force = true)
                @test true
            else
                @test isfile(ref_path)
            end
            return fig
        end

        img_ref = PNGFiles.load(ref_path)
        img_rec = PNGFiles.load(rec_path)
        num_diff, diff_img = PixelMatch.pixelmatch(img_ref, img_rec)

        if num_diff == 0
            @test true
            return fig
        end

        PNGFiles.save(diff_path, diff_img)
        println("Reference test failed for: $name [$backend]")
        println("  Reference: $ref_path")
        println("  Recorded:  $rec_path")
        println("  Diff:      $diff_path")
        println("  Pixels different: $num_diff")

        if isinteractive() && update
            cp(rec_path, ref_path; force = true)
            println("Reference image updated.")
            @test true
        else
            @test false
        end
    end
    return fig
end
