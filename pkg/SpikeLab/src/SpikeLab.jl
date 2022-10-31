module SpikeLab

using Reexport
using Distributions
# Don't `@reexport`: this macro somehow also exports our own `LogNormal` (see below),
# creating a conflict.

include("spikefeed.jl")

include("poisson.jl")
export poisson_spikes

include("distributions.jl")
# Don't export LogNormal, to not conflict with Distributions.jl
# Instead, use `SpikeLab.LogNormal` to use our parametrization.

include("misc.jl")
export to_timesteps

include("eqparse.jl")
export @eqs

include("model.jl")
export Model, PoissonInput, sim!

include("latex.jl")
export show_eqs

end
