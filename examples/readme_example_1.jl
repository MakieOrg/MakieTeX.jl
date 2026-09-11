using Makie
include("../src/MakieTeX.jl")
using .MakieTeX
using CairoMakie # or whichever other backend

# Get Ghostscript path from the environment variable
ghostscript_path = get(ENV, "GHOSTSCRIPT_PATH", "/usr/bin/gs")  # Fallback to a default path if not set

# Set MakieTeX to use the custom Ghostscript path
MakieTeX.Ghostscript_jll.gs() = ghostscript_path

# Print to confirm the overridden path
println("Using Ghostscript at: ", MakieTeX.Ghostscript_jll.gs())

fig = Figure()
l1 = LTeX(
    fig[1, 1], L"A \emph{convex} function $f \in C$ is \textcolor{blue}{denoted} as \tikz{\draw[line width=1pt, >->] (0, -2pt) arc (-180:0:8pt);}";
    tellwidth = false, tellheight = true
)
ax1 = Axis(
    fig[2, 1];
)
heatmap!(ax1, Makie.peaks())

display(fig)

# Save the figure to a file in the current directory
output_dir = "examples/out"
output_filename = "output_image_1.png"
img_output_path = joinpath(output_dir, output_filename)

# Check if the directory exists, else create it
if !isdir(output_dir)
    println("Directory $output_dir does not exist. Creating it...")
    mkdir(output_dir)
end

println("Saving the figure to $img_output_path")
save(img_output_path, fig)
