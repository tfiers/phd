module SpikeLab

using Distributions
# Don't `@reexport`: this macro somehow also exports our own `LogNormal` (see below),
# creating a conflict.
using ComponentArrays: CVector  # alias for ComponentVector


include("spikefeed.jl")

include("distributions.jl")
# Don't export LogNormal, to not conflict with Distributions.jl
# Instead, use `SpikeLab.LogNormal` to use our parametrization.

include("misc.jl")
export to_timesteps

include("eqparse.jl")
export @eqs

include("sim.jl")
export Model, sim

include("poisson.jl")
export poisson_spikes, PoissonInput

include("latex.jl")
export show_eqs

end
