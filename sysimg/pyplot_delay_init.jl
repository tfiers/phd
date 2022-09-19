
# See https://github.com/JuliaPy/PyPlot.jl/pull/480
# and ./to_precompile.jl
# Needs
#    Pkg.add(url="https://github.com/xzackli/PyPlot.jl")

using PyPlot
PyPlot.delay_init_until_cell[] = true
