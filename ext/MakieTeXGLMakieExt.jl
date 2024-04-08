module MakieTeXGLMakieExt
#=
This extension tells GLMakie how to rasterize a cached document, if it is required.
=#
using GLMakie, MakieTeX

GLMakie.GLAbstraction.gl_convert(ct::AbstractCachedDocument) = MakieTeX.rasterize_and_cache(ct, #=scale=#1)
GLMakie.GLAbstraction.gl_convert((ct::AbstractCachedDocument, scale::Real)) = MakieTeX.rasterize_and_cache(ct, scale)

end