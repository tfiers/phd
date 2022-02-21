module VoltageToMap

using MyToolbox
using Distributions  # Sample from lognormal, exponential, ….

include("units.jl")
export mega, kilo, milli, centi, micro, nano, pico
export s, seconds, ms, minutes, hours, Hz, cm, mm, μm, um, nm
export μA, uA, nA, pA, volt, mV, nV, mS, nS, ohm, Mohm, uF, μF, nF, pF

include("misc.jl")
export LogNormal_with_mean

include("params.jl")
export PoissonInputParams, realistic_input, small_N__as_in_Python_2021
export SynapseParams, semi_arbitrary_synaptic_params
export IzhNeuronParams, cortical_RS
export SimParams

include("sim_init.jl")
include("sim_step.jl")
include("sim.jl")
export sim

end
