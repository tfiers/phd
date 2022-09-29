module VoltoMapSim

using MyToolbox: @reexport
@reexport using MyToolbox
@reexport using Sciplotlib
@reexport using Distributions  # Sample from lognormal, exponential, ….
@reexport using DataFrames


const datamodel_version = "2 (net)"
    # Used in diskcache.jl


include("units.jl")
# [see file for exports]

include("misc.jl")
export LogNormal_with_mean, ptp, area_over_start, bin
export jn, print_type_compactly

include("params.jl")
@alias ExpParams = ExperimentParams
export get_params, ExperimentParams, ExpParams

include("diskcache.jl")
export cached, cachefilename

include("sim/sim.jl")
export sim, add_VI_noise, augment, calc_avg_STA

include("conntest.jl")
export calc_STA, to_ISIs, to_spiketimes!, shuffle_ISIs, test_connection

include("eval.jl")
export evaluate_conntest_perf, cached_conntest_eval

include("plot.jl")
export color_exc, color_inh, color_unconn
export plotsig, plotSTA
export rasterplot, histplot_fr
export plot_detection_rates, plot_samples_and_means, add_α_line, extract
export ydistplot, add_refline


function __init__()
    set_print_precision(3)
end

end # module VoltoMapSim
