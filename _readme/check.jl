# PixelMatch the freshly-rendered README PNGs against the versions
# committed at HEAD. Text-only diff for README.md is handled by
# `git diff --exit-code -- README.md` in CI; this script is just for
# the binary PNG assets. Matches the strict-equality policy used by
# the rest of the reference tests — no per-pixel tolerance, any
# mismatch fails.

using Pkg
Pkg.activate(@__DIR__)

using PixelMatch
using PNGFiles

const REPO = abspath(joinpath(@__DIR__, ".."))
const PNG_ROOT_REL = "README_files"
const PNG_ROOT = joinpath(REPO, PNG_ROOT_REL)

function head_bytes(rel)
    try
        return read(`git -C $REPO show HEAD:$rel`)
    catch
        return nothing
    end
end

function load_head_png(rel)
    bytes = head_bytes(rel)
    bytes === nothing && return nothing
    return PNGFiles.load(IOBuffer(bytes))
end

is_rendered_png(file) = endswith(file, ".png") &&
    !occursin(r"_(diff|ref|rec)\.png$", file)

function check_pngs()
    failed = String[]
    total  = 0

    for (root, _, files) in walkdir(PNG_ROOT), file in files
        is_rendered_png(file) || continue
        abs = joinpath(root, file)
        rel = relpath(abs, REPO)
        total += 1

        new_img = PNGFiles.load(abs)
        old_img = load_head_png(rel)
        base = replace(abs, r"\.png$" => "")

        if old_img === nothing
            @warn "No HEAD version of PNG; treating as new" rel
            push!(failed, rel)
            continue
        end
        if size(new_img) != size(old_img)
            @warn "PNG size changed" rel size(new_img) size(old_img)
            PNGFiles.save(base * "_ref.png", old_img)
            push!(failed, rel)
            continue
        end

        n_diff, diff_img = PixelMatch.pixelmatch(old_img, new_img; threshold = 0)
        if n_diff > 0
            @warn "PixelMatch mismatch" rel n_diff
            PNGFiles.save(base * "_ref.png", old_img)
            PNGFiles.save(base * "_diff.png", diff_img)
            push!(failed, rel)
        end
    end

    # Catch files that existed in HEAD but were not regenerated.
    head_listing = String[]
    try
        head_listing = readlines(`git -C $REPO ls-tree -r --name-only HEAD -- $PNG_ROOT_REL`)
    catch
        # No previous tree — first-time render, that's fine.
    end
    for rel in head_listing
        is_rendered_png(rel) || continue
        if !isfile(joinpath(REPO, rel))
            @warn "PNG removed from rendered output" rel
            push!(failed, rel)
        end
    end

    return total, failed
end

total, failed = check_pngs()

if isempty(failed)
    println("README PNG check: $(total) image(s) match HEAD exactly.")
else
    println("README PNG check: $(length(failed)) failure(s) out of $(total):")
    foreach(f -> println("  $f"), failed)
    exit(1)
end
