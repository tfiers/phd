module VoltoMapSim

using MyToolbox: @reexport
@reexport using MyToolbox
@reexport using Distributions  # Sample from lognormal, exponential, ….


const datamodel_version = "2 (net)"
    # Used in diskcache.jl


include("units.jl")
# [see file for exports]

include("misc.jl")
export LogNormal_with_mean, ptp, area, bin

include("params.jl")
export get_params

include("diskcache.jl")
export cached, cachefilename

include("sim/sim.jl")
export sim, add_VI_noise, augment_simdata, get_input_info

include("conntest.jl")
export calc_STA, to_ISIs, to_spiketimes!, shuffle_ISIs, test_connection

include("eval.jl")
export evaluate_conntest_perf, sim_and_eval, cached_conntest_perf


function __init__()
    set_print_precision(3)
end


"""
Custom plotting functions are in this separate submodule, so that the heavy PyPlot does not
need to be loaded when plotting is not needed.
"""
module Plot
using ..VoltoMapSim
function __init__()
    @require PyPlot = "d330b81b-6aea-500a-939a-2ce795aea3ee" begin
        include("plot.jl")
        export color_exc, color_inh, color_unconn
        export plotsig, plotSTA
        export rasterplot, histplot_fr
        export plot_detection_rates, plot_samples_and_means, add_α_line, extract
        export ydistplot, add_refline
    end
end
end # module Plot


end # module VoltoMapSim
