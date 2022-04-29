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

# # 2022-04-28 • Interpolate N = 30 .. 6000

# The N = 30 case had a fixed firing rate for the input neurons (of 20 Hz).  
# We'll now also give it the lognormal (with mean 4 Hz) firing rate distribution.
#
# We must introduce a new concept / parameter: the desired **stimulation rate** of the input neurons.
# It is a product of average firing rate and 'stimulation' (synaptic conductance increase, Δg) per spike.
# Given that average spike rate is fixed (namely 4 Hz), we use this paramter to calculate Δg.
#
# A sensible value for it is taken from the previous (N = 6600) notebook
# where Δg_exc was 0.4 nS and the Δg_multiplier was 0.066.
#
# We'll thus choose `avg_stimulation_rate__exc` to be 0.4 nS * 0.066 * 4 Hz, or **0.1 nS/second**.
# Our inhibitory inputs have 4x the strength, so `avg_stimulation_rate__inh` will be **0.4 nS/second**.
#
# The actual stimulation rate for each input neuron will vary from these, as their firing rates are not 4 Hz, but rather distributed lognormally somewhere around that.

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
);

param_sets = get_params.(N_excs);

dumps(param_sets[1])

# ## Run

perfs = Vector()
for params in param_sets
    @show params.sim.input.N_conn
    perf = performance_for(params)
    @show perf
    push!(perfs, perf)
    println()
end

# ## Plot results

import PyPlot

using VoltageToMap.Plot

# +
xlabels = [p.sim.input.N_conn for p in param_sets]
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

@unpack α = param_sets[1].evaluation
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

# - We see monotonic breakdown in excitatory connection detectability.
# - Same for inhibitory, except it's not monotonic. Fluke due to sampling?
# - This plot must be improved with multiple simulations per condition rather than just single point.  
#   (takes a while to run multiple 10' N=6500 sims though).
