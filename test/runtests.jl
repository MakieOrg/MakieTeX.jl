using Test
using MakieTeX
using Makie
using CairoMakie, GLMakie
using LaTeXStrings
using Typstry
using PixelMatch
using tectonic_jll  # activates MakieTeXLaTeXExt

include("reference_tests.jl")

@testset "MakieTeX reference tests" begin
    @testset "CairoMakie" begin
        run_reftests(:CairoMakie)
    end
    @testset "GLMakie" begin
        run_reftests(:GLMakie)
    end
end
