using Makie
include("../src/MakieTeX.jl")
using .MakieTeX
using CairoMakie # or whichever other backend

println("testing MakieTeX")

# log which tex engine is being used
println("Using TeX engine: $(MakieTeX.CURRENT_TEX_ENGINE[])")

fig = Figure(size = (400, 300), pt_per_unit = 2);
tex1 = LTeX(
    fig[1, 1], 
    L"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}", 
    scale=1,
    render_density = 2,
);
tex2 = LTeX(
    fig[2, 1], 
    L"\int \mathbf E \cdot d\mathbf a = \frac{Q_{encl}}{4\pi\epsilon_0}", 
    scale=2,
    render_density = 2,
);

# Save the figure to a file in the current directory
output_dir = "examples/out"
output_filename = "output_image_2.png"
img_output_path = joinpath(output_dir, output_filename)

# Check if the directory exists, else create it
if !isdir(output_dir)
    println("Directory $output_dir does not exist. Creating it...")
    mkdir(output_dir)
end

println("Saving the figure to $img_output_path")
save(img_output_path, fig)
