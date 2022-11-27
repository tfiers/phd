module SpikeLab

using Reexport
using Distributions
# ↪ Don't `@reexport Distriubtions`: this macro somehow also exports our own `LogNormal`
#   (see below), creating a conflict.
@reexport using ComponentArrays: CVector                # Alias for ComponentVector
@reexport using ComponentArrays: Axis, ComponentVector  # For unqualified typenames in errors
using Base: RefValue
# ↪ `Ref` is abstract, so bad for perf as struct field. `RefValue` is the concrete subtype.
#    As this is not exported from Base, nor documented, it's not public api and can thus
#    change. Better would thus be to `MyStruct{T<:Ref{Int}} … field:T`,
#    instead of `MyStruct … field:RefValue{Int}`, as it is now.

include("units.jl")
include("spikefeed.jl")
include("distributions.jl")
# ↪ Don't export LogNormal, to not conflict with Distributions.jl
#   Instead, use `SpikeLab.LogNormal` to use our parametrization.
include("misc.jl");       export to_timesteps
include("spiketrain.jl"); export SpikeTrain
include("eqparse.jl");    export @eqs
include("sim.jl");        export Model, sim, init_sim, step!, SimState
include("poisson.jl");    export poisson_spikes, poisson_SpikeTrain
include("latex.jl");      export show_eqs

end # module
