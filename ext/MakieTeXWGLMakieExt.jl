module MakieTeXWGLMakieExt

using WGLMakie, MakieTeX

WGLMakie.wgl_convert(ct::AbstractCachedDocument) = MakieTeX.rasterize_and_cache(ct, #=scale=#1)
WGLMakie.wgl_convert((ct::AbstractCachedDocument, scale::Real)) = MakieTeX.rasterize_and_cache(ct, scale)


end