module VoltageToMap

using MyToolbox
using Distributions  # Sample from lognormal, exponential, ….

include("units.jl")
# [see file for exports]

include("misc.jl")
export LogNormal_with_mean

include("params.jl")
export ExperimentParams, SimParams, ConnTestParams, EvaluationParams
export PoissonInputsParams, SynapseParams, IzhikevichParams, VoltageImagingParams
export realistic_N_6600_inputs, previous_N_30_inputs, realistic_synapses, cortical_RS,
       get_voltage_imaging_params, params

include("sim.jl")
export sim

end
