module MakieTeXWGLMakieExt

using WGLMakie, MakieTeX

WGLMakie.wgl_convert(ct::AbstractCachedDocument) = MakieTeX.rasterize(ct, #=scale=#1)
WGLMakie.wgl_convert((ct::AbstractCachedDocument, scale::Real)) = MakieTeX.rasterize(ct, scale)


end