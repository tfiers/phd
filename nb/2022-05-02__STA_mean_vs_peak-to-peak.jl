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
#     80,
#     320,
#     1280,
#     5200,  
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

paramset = paramsets[1]
dir = joinpath(homedir(), ".phdcache")
mkpath(dir)
path = joinpath(dir, "$(hash(paramset)).hdf5")

@save path paramset
