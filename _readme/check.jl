# Compare the freshly-rendered README PNGs against the versions committed at HEAD,
# as files first: identical bytes pass without decoding, and a file that differs
# only in its `pHYs` resolution still fails, since Quarto sizes the embedded image
# from it. Text-only diff for README.md is handled by `git diff --exit-code --
# README.md` in CI; this script is just for the binary PNG assets. No per-pixel
# tolerance, any mismatch fails.

using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

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

# The HEAD version is written out as the bytes git holds rather than re-encoded from
# a decoded image, so the reference file in the report is the committed file, DPI and
# all, instead of a default-encoded copy of its pixels.
function write_head_png(path, bytes)
    write(path, bytes)
    return path
end

"""
    png_dpi(bytes)

Pixels per metre from a PNG's `pHYs` chunk, or `nothing` if it carries none. Quarto
embeds the images at a size derived from this, so two files with identical pixels
still render differently when it differs.
"""
function png_dpi(bytes::Vector{UInt8})
    pos = 9  # past the signature
    while pos + 8 <= length(bytes)
        len = Int(only(reinterpret(UInt32, reverse(bytes[pos:(pos + 3)]))))
        type = String(bytes[(pos + 4):(pos + 7)])
        type == "pHYs" && return (
            Int(only(reinterpret(UInt32, reverse(bytes[(pos + 8):(pos + 11)])))),
            Int(only(reinterpret(UInt32, reverse(bytes[(pos + 12):(pos + 15)])))),
        )
        type == "IDAT" && return nothing  # metadata chunks all precede the data
        pos += len + 12
    end
    return nothing
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

        new_bytes = read(abs)
        old_bytes = head_bytes(rel)
        base = replace(abs, r"\.png$" => "")

        if old_bytes === nothing
            @warn "No HEAD version of PNG; treating as new" rel
            PixelMatch._record_failure(; name = rel, status = :missing_ref, rec_path = abs)
            push!(failed, rel)
            continue
        end
        # Compare the files, not their pixels: a rendered PNG that differs only in
        # its DPI still displays at the wrong size in the README.
        new_bytes == old_bytes && continue

        new_img = PNGFiles.load(abs)
        old_img = PNGFiles.load(IOBuffer(old_bytes))
        ref_path = write_head_png(base * "_ref.png", old_bytes)

        if size(new_img) != size(old_img)
            @warn "PNG size changed" rel size(new_img) size(old_img)
            PixelMatch._record_failure(;
                name = rel, status = :size_mismatch, ref_path, rec_path = abs,
                ref_size = size(old_img), rec_size = size(new_img)
            )
            push!(failed, rel)
            continue
        end

        n_diff, diff_img = PixelMatch.pixelmatch(old_img, new_img; threshold = 0)
        if n_diff > 0
            @warn "PixelMatch mismatch" rel n_diff
            PNGFiles.save(base * "_diff.png", diff_img)
            PixelMatch._record_failure(;
                name = rel, status = :mismatch, num_pixels_diff = n_diff,
                ref_path, rec_path = abs, diff_path = base * "_diff.png",
                ref_size = size(old_img), rec_size = size(new_img)
            )
        elseif png_dpi(new_bytes) != png_dpi(old_bytes)
            @warn "PNG resolution changed" rel new = png_dpi(new_bytes) old = png_dpi(old_bytes)
            PixelMatch._record_failure(;
                name = rel, status = :mismatch, num_pixels_diff = 0,
                ref_path, rec_path = abs, ref_size = size(old_img), rec_size = size(new_img)
            )
        else
            # same pixels at the same resolution, so the bytes differ only in how the
            # encoder wrote them
            rm(ref_path)
            continue
        end
        push!(failed, rel)
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
            PixelMatch._record_failure(; name = rel, status = :missing_rec)
            push!(failed, rel)
        end
    end

    return total, failed
end

PixelMatch.@pixelmatch_report out_file = joinpath(@__DIR__, "pixelmatch-report.html") begin
    global total, failed = check_pngs()
end

if isempty(failed)
    println("README PNG check: $(total) image(s) match HEAD exactly.")
else
    println("README PNG check: $(length(failed)) failure(s) out of $(total):")
    foreach(f -> println("  $f"), failed)
    exit(1)
end
