module VoltageToMap

using MyToolbox
using Distributions  # Sample from lognormal, exponential, ….

include("units.jl")
# [see file for exports]

include("misc.jl")
export LogNormal_with_mean

include("params.jl")
export PoissonInputParams, realistic_input, small_N__as_in_Python_2021
export SynapseParams, semi_arbitrary_synaptic_params
export IzhNeuronParams, cortical_RS
export SimParams

include("sim.jl")
export sim

end
