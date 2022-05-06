module VoltageToMap

using MyToolbox: @reexport
@reexport using MyToolbox
@reexport using Distributions  # Sample from lognormal, exponential, ….


include("units.jl")
# [see file for exports]

include("misc.jl")
export LogNormal_with_mean, ptp

include("params.jl")
export ExperimentParams, SimParams, ConnTestParams, EvaluationParams
export PoissonInputParams, SynapseParams, IzhikevichParams, VoltageImagingParams
export realistic_N_6600_input, previous_N_30_input, realistic_synapses, cortical_RS,
get_VI_params_for, params

include("diskcache.jl")
export cached, cachefilename

include("sim.jl")
export sim

include("conntest.jl")
export calc_STA, to_ISIs, to_spiketimes!, shuffle_ISIs, test_connection

include("eval.jl")
export evaluate_conntest_performance, sim_and_eval


"""
Custom plotting functions are in this separate submodule, so that the heavy PyPlot does not
need to be loaded when plotting is not needed.
"""
module Plot
using ..VoltageToMap
function __init__()
    @require PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee" begin
        include("plot.jl")
        export plotsig, plotSTA, plot_samples_and_means, add_α_line
        export color_exc, color_inh, color_unconn
    end
end
end # module Plot


end # module VoltageToMap
