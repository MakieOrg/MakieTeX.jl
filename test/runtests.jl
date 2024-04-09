using MakieTeX
using MakieTeX.Makie
using CairoMakie
using Downloads

using Test

example_path = joinpath(@__DIR__, "test_images")
mkpath(example_path)

function save_test(filename, fig; kwargs...)

    save(joinpath(example_path, "$filename.png"), fig; px_per_unit=3, kwargs...)
    save(joinpath(example_path, "$filename.pdf"), fig; px_per_unit=1, kwargs...)
    save(joinpath(example_path, "$filename.svg"), fig; px_per_unit=0.75, kwargs...)

end

include("tex.jl")
include("svg.jl")
