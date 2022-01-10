
# https://discourse.julialang.org/t/modifying-the-time-macro/2790/8
"""Print a (slow) expression, then execute it. Goal: the user knows why cell hangs."""
macro monitor(expr)
    quote
        println($(Meta.quot(expr)))
        flush(stdout)
        esc($(expr))
    end
end

@monitor using Revise               # Auto-reload the packages below when they are changed
@monitor using PyFormattedStrings,  # f-strings as in Python (but with C format spec)
               Distributions,       # Sample from lognormal, exponential, ….
               Unitful
@monitor using Unitful: mV, Hz, ms, s, minute
# @monitor using Plots                # Julia unified plotting API
# @monitor using PyPlot               # Matplotlib API
@monitor using VoltageToMap         # Our own code, in [root]/src/
