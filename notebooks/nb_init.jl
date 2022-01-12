
"""Print a slow expression, then execute it. Goal: the user knows why cell hangs."""
macro print(expr)
    quote
        println($(Meta.quot(expr)))
        flush(stdout)
        esc($(expr))
    end
end  # (src https://discourse.julialang.org/t/modifying-the-time-macro/2790/8)


@print using Revise               # Auto-reloads our codebase when it is changed
@print using Distributions,       # Sample from lognormal, exponential, ….
    PyFormattedStrings,  # f-strings as in Python (but with C format spec)
    PartialFunctions,    # `f $ a` (like `partial(f, a)` in Python)
    FilePaths,           # `Path` type and `/` joins, as in Python
    LaTeXStrings
using FilePathsBase: /
@print using Unitful: mV, Hz, ms, s, minute
using Unitful
@print import PyPlot as plt       # Matplotlib API
import PyPlot: matplotlib as mpl
@print using VoltageToMap         # Our own code, in [root]/src/


rcParams = plt.PyDict(plt.matplotlib."rcParams")
#   String quotes prevent conversion from Python to Julia dict, 
#   so that mutating the dict has effect.

merge!(rcParams, plt.matplotlib.rcParamsOrig)
#   Reset, so that we can remove properties from `style` when experimenting.
merge!(rcParams, style)
