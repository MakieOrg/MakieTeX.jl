module MakieTeXGLMakieExt
#=
This extension tells GLMakie how to rasterize a cached document, if it is required.
=#
using GLMakie, MakieTeX

GLMakie.GLAbstraction.gl_convert(ct::MakieTeX.AbstractCachedDocument) = MakieTeX.rasterize(ct, #=scale=#1)
# GLMakie.GLAbstraction.gl_convert((ct::MakieTeX.AbstractCachedDocument, scale::Real)) = MakieTeX.rasterize(ct, scale)

end