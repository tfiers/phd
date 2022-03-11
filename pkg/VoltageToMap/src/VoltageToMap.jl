module VoltageToMap

using Reexport

@reexport using MyToolbox
@reexport using Distributions  # Sample from lognormal, exponential, ….

include("units.jl")
# [see file for exports]

include("misc.jl")
export LogNormal_with_mean

include("params.jl")
export ExperimentParams, SimParams, ConnTestParams, EvaluationParams
export PoissonInputParams, SynapseParams, IzhikevichParams, VoltageImagingParams
export realistic_N_6600_input, previous_N_30_input, realistic_synapses, cortical_RS,
       get_voltage_imaging_params, params

include("sim.jl")
export sim

end
