module VoltoMapSim

using MyToolbox: @reexport
@reexport using MyToolbox
@reexport using Sciplotlib
@reexport using Distributions  # Sample from lognormal, exponential, ….
@reexport using DataFrames
@reexport using LsqFit

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
export fit_STA, toCVec, FitParams, model_STA, model_STA_components, centre

include("infer/shuffle_test.jl")
export shuffle_ISIs, calc_pval

include("infer/test_conn.jl")
export test_conns, test_conn__corr, test_conn__ptp
export ptp, area_over_start

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
