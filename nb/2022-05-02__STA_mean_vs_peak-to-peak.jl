# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.7
#   kernelspec:
#     display_name: Julia 1.7.1
#     language: julia
#     name: julia-1.7
# ---

# # 2022-05-02• STA mean vs peak-to-peak

# Peak-to-peak cannot distinguish excitatory vs inhibitory (it's just the height of the bump -- no matter whether it's upwards or downwards).
#
# To do that, we might instead use sth like "either max-median or min-median, whatever's largest in absolute terms".
#
# For now we don't try to detect this difference, and 'cheat' in our code (special-case the inhibitory / ptp case when comparing p-values with α).

# ## Setup

# +
#
# -

using Revise

using MyToolbox

using VoltageToMap

# ## Params

N_excs = [
    4,   # => N_inh = 1
    17,  # Same as in `previous_N_30_input`.
    80,
    320,
    1280,
    5200,  
];

get_params(N_exc) = ExperimentParams(
    sim = SimParams(
        duration = 10 * minutes,
        imaging = get_VI_params_for(cortical_RS, spike_SNR = Inf),
        input = PoissonInputParams(; N_exc),
    ),
    conntest = ConnTestParams(STA_test_statistic="ptp")
);

paramsets = get_params.(N_excs);

dumps(paramsets[1])

# ## Run

perfs = Vector()
for paramset in paramsets
    num_inputs = paramset.sim.input.N_conn
    @show num_inputs
    perf = performance_for(paramset)
    @show perf
    push!(perfs, perf)
    println()
end

# ## Plot results

import PyPlot

using VoltageToMap.Plot

# +
xlabels = [p.sim.input.N_conn for p in paramsets]
xticks = [1:length(xlabels);]
plot_detection_rate(detection_rate; kw...) = plot(
    xticks,
    detection_rate,
    ".-";
    ylim=(0, 1),
    xminorticks=false,
    clip_on=false,
    kw...
)
ax = plot_detection_rate([p.TPR_exc for p in perfs], label="for excitatory inputs")
     plot_detection_rate([p.TPR_inh for p in perfs], label="for inhibitory inputs")
     plot_detection_rate([p.FPR for p in perfs], label="for unconnected spikers")

@unpack α = paramsets[1].evaluation
ax.axhline(α, color="black", zorder=3, lw=1, linestyle="dashed", label=f"α = {α:.3G}")

# We don't use our `set`, as that undoes our `xminorticks=false` command (bug).
ax.set_xticks(xticks, xlabels)
ax.set_xlabel("Number of connected inputs")
ax.yaxis.set_major_formatter(PyPlot.matplotlib.ticker.PercentFormatter(xmax=1))
ax.xaxis.grid(false)
ax.tick_params(bottom=false)
ax.spines["bottom"].set_visible(false)
l = ax.legend(title="Detection rate", ncol=2, loc="lower center", bbox_to_anchor=(0.5, 1.1));
l._legend_box.align = "left";
# -

# ## [experiment with JLD]

simparams = SimParams()

cached(sim, [simparams])

cached(sim, [simparams])

@withfb "sl" sleep(3)



output = sim(simparams);

dir = joinpath(homedir(), ".phdcache")
mkpath(dir)
path = joinpath(dir, string(hash(simparams), base=16) * ".hdf5")

# - https://github.com/JuliaIO/JLD.jl
# - https://docs.julialang.org/en/v1/base/file/#Base.Filesystem.isfile
# - https://github.com/JuliaIO/JLD.jl/blob/master/doc/jld.md

joinpath(homedir(), nothing)

jldsave(path2; simparams, output)

path2 = joinpath(dir, "blah.jld2")

jldsave(path2; output)

l = load(path2)

o = l["output"];

homedir() / p".phdcache"

o.input_spikes.conn.exc[1]




