
# Hi-def ('retina') figures in notebook.
# [https://github.com/JuliaLang/IJulia.jl/pull/918]
function IJulia.metadata(x::PythonPlot.Figure)
    fw = pyconvert(Float64, x.get_figwidth())
    fh = pyconvert(Float64, x.get_figheight())
    dpi = pyconvert(Float64, x.get_dpi())
    w, h = (fw, fh) .* dpi
    return Dict("image/png" => Dict("width" => 0.5 * w, "height" => 0.5 * h))
end
