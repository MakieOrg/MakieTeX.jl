# Prune the reference_images/ tree to just the images for tests that
# actually failed — i.e. those with a *_diff.png next to them. PixelMatch
# writes _rec / _diff only on mismatch, so the presence of a _diff is the
# failure marker. Used by CI before uploading the artifact.

function filter_failed(plots_dir::String)
    isdir(plots_dir) || return
    diff_files = String[]
    for (root, _, files) in walkdir(plots_dir), file in files
        endswith(file, "_diff.png") && push!(diff_files, joinpath(root, file))
    end

    bases = Set{String}(replace(f, r"_diff\.png$" => "") for f in diff_files)
    foreach(b -> println("kept: $b"), bases)

    for (root, _, files) in walkdir(plots_dir), file in files
        endswith(file, ".png") || continue
        path = joinpath(root, file)
        if !any(b -> path in ("$(b)_diff.png", "$(b)_ref.png", "$(b)_rec.png"), bases)
            println("removed: $path")
            rm(path)
        end
    end

    println("filter complete: kept $(length(bases)) failed test(s)")
end

filter_failed(joinpath(@__DIR__, "reference_images"))
