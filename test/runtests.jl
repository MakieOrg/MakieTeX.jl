using Test
using MakieTeX
using Makie
using CairoMakie
using LaTeXStrings
using Typstry
using PixelMatch
using tectonic_jll  # activates MakieTeXLaTeXExt

# GLMakie needs a GPU; Windows / macOS GitHub-hosted runners don't have one,
# so skip the GL reftests there. Linux CI has xvfb. Locally everyone has a
# GPU. The CI workflow Pkg.rm's GLMakie on Windows / macOS to match.
const SKIP_GLMAKIE = get(ENV, "CI", "false") == "true" && (Sys.isapple() || Sys.iswindows())

if !SKIP_GLMAKIE
    using GLMakie
end

include("reference_tests.jl")

PixelMatch.@pixelmatch_report out_file = joinpath(@__DIR__, "pixelmatch-report.html") begin
    @testset "MakieTeX reference tests" begin
        @testset "CairoMakie" begin
            run_reftests(:CairoMakie)
        end
        if !SKIP_GLMAKIE
            @testset "GLMakie" begin
                run_reftests(:GLMakie)
            end
        end
    end
end
