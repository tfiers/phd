module VoltoMapSim

using MyToolbox: @reexport
@reexport using MyToolbox
@reexport using Sciplotlib
@reexport using SpikeWorks
@reexport using Distributions  # Sample from lognormal, exponential, ….
@reexport using DataFrames
@reexport using LsqFit
@reexport using ForwardDiff

using Base.Threads


include("units.jl")
# [see file for exports]

include("misc.jl")
export LogNormal_with_mean, bin, jn, fmt_pct, sprintf, print_type_compactly

include("params.jl")
@alias ExpParams = ExperimentParams
export get_params, ExperimentParams, ExpParams

include("diskcache.jl")
export cached, cachedir, cachepath, savecache, loadcache, empty_cache

include("sim/sim.jl")
export sim, init_sim, step_sim!, add_VI_noise, augment, dummy_simdata

include("infer/sample_conns.jl")
export get_connections_to_test, summarize_conns_to_test

include("infer/calc_STA.jl")
export calc_STA, calc_all_STAs, cached_STAs, STA_win_size

include("infer/model_STA.jl")
export STA_modelling_funcs, centre, toParamCVec

include("infer/shuffle_test.jl")
export shuffle_ISIs, calc_pval

include("infer/test_conn.jl")
export test_conn, test_conns
export corr_test, ptp_test, modelfit_test
export ptp, area_over_start, MSE

include("infer/perfmeasures.jl")
export perfmeasures, perftable

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
