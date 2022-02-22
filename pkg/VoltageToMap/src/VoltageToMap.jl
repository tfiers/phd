module VoltageToMap

using MyToolbox
using Distributions  # Sample from lognormal, exponential, ….

include("units.jl")
# [see file for exports]

include("misc.jl")
export LogNormal_with_mean

include("params.jl")
export ExperimentParams, SimParams, ConnTestParams, EvaluationParams
export PoissonInputsParams, SynapseParams, IzhikevichNeuronParams, VoltageImagingParams
export realistic_input, N_30_input, realistic_synapses, cortical_RS, get_voltage_imaging_params

include("sim.jl")
export sim

end
