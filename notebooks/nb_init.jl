
"""Print a slow expression, then execute it. Goal: the user knows why cell hangs."""
macro print(expr)
    quote
        println($(Meta.quot(expr)))
        flush(stdout)
        esc($(expr))
    end
end  # (src: https://discourse.julialang.org/t/modifying-the-time-macro/2790/8)


@print using Revise               # Auto-reloads our codebase when it is changed.
@print using Distributions        # Sample from lognormal, exponential, ….
@print using DataFrames           # Tables.
@print using PartialFunctions: $  # Currying (`func $ a`, like `partial(func, a)` in Python).
@print using PyFormattedStrings,  # f-strings as in Python (but with C format spec).
             LaTeXStrings,        # `L"These strings can contain $ and \ without escaping"`.
             FilePaths,           # `Path` type and `/` joins, as in Python.
             Colors
       using FilePathsBase: /
@print using Unitful: mV, Hz, ms, s as second, minute
       using Unitful
@print using PyPlot: PyPlot as plt, matplotlib as mpl  # Matplotlib API.

@print using VoltageToMap         # Our own code, in [root]/src/.


function savefig(fname; subdir)
    "figdir" in keys(ENV) || error("Environment variable `figdir` not set.")
    dir = Path(ENV["figdir"]) / subdir
    exists(dir) || mkpath(dir)
    plt.savefig(string(dir / fname))
end

# Hi-def ('retina') figures in notebook. [https://github.com/JuliaLang/IJulia.jl/pull/918]
function IJulia.metadata(x::plt.Figure)
    w, h = (x.get_figwidth(), x.get_figheight()) .* x.get_dpi()
    return Dict("image/png" => Dict("width" => 0.5 * w, "height" => 0.5 * h))
end

# Matplotlib settings.
rcParams = plt.PyDict(mpl."rcParams") # String quotes prevent conversion from Python to 
                                      # Julia dict, so that mutating the dict affects mpl.
merge!(rcParams, mpl.rcParamsOrig) # Reset, so that we can remove properties from
                                   # `VoltageMap.style` in an interactive session.
merge!(rcParams, VoltageToMap.mplstyle)
;
