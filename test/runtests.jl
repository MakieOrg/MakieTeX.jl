using Test
using MakieTeX
using Makie
using CairoMakie
using LaTeXStrings
using Typstry
using PixelMatch
using tectonic_jll  # activates MakieTeXLaTeXExt

# GLMakie needs a GPU; Windows / macOS CI runners don't have one. The CI
# workflow Pkg.rm's GLMakie on those OSes so the import below errors and
# we skip the GL reftests. Linux CI runs with xvfb so GL is fine there.
const HAS_GLMAKIE = try
    @eval using GLMakie
    true
catch err
    @warn "GLMakie unavailable; skipping :GLMakie reference tests" exception = err
    false
end

include("reference_tests.jl")

@testset "MakieTeX reference tests" begin
    @testset "CairoMakie" begin
        run_reftests(:CairoMakie)
    end
    if HAS_GLMAKIE
        @testset "GLMakie" begin
            run_reftests(:GLMakie)
        end
    end
end
