module SpikeLab

using Reexport
using Distributions
# ↪ Don't `@reexport Distriubtions`: this macro somehow also exports our own `LogNormal`
#   (see below), creating a conflict.
@reexport using ComponentArrays: CVector                # Alias for ComponentVector
@reexport using ComponentArrays: Axis, ComponentVector  # For unqualified typenames in errors

include("units.jl")
include("spikefeed.jl")
include("distributions.jl")
# ↪ Don't export LogNormal, to not conflict with Distributions.jl
#   Instead, use `SpikeLab.LogNormal` to use our parametrization.
include("misc.jl");     export to_timesteps
include("eqparse.jl");  export @eqs
include("sim.jl");      export Model, sim, init_sim, step!, SimState
include("poisson.jl");  export poisson_spikes, poisson_input
include("latex.jl");    export show_eqs

end # module
