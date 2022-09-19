
# See https://github.com/JuliaPy/PyPlot.jl/pull/480
# and ./to_precompile.jl
# Needs
#    Pkg.add(url="https://github.com/xzackli/PyPlot.jl")

import PyPlot  # `import` instead of `using`, so we do not import all the names.

PyPlot.delay_init_until_cell[] = true
