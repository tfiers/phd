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

rngseeds = [0:16;];

get_params((N_exc, STA_test_statistic, rngseed)) = ExperimentParams(
    sim = SimParams(
        duration = 10 * minutes,
        imaging = get_VI_params_for(cortical_RS, spike_SNR = Inf),
        input = PoissonInputParams(; N_exc);
        rngseed,
    ),
    conntest = ConnTestParams(; STA_test_statistic, rngseed);
    evaluation = EvaluationParams(; rngseed)
);

variableparams = collect(product(N_excs, ["ptp", "mean"], rngseeds));

paramsets = get_params.(variableparams);
print(summary(paramsets))

dumps(paramsets[1])

# ## Run

perfs = similar(paramsets, NamedTuple)
for i in eachindex(paramsets)
    (N_exc, stat, seed) = variableparams[i]
    paramset = paramsets[i]
    println((; N_exc, stat, seed), " ", cachefilename(paramset))
    perf = cached(sim_and_eval, [paramset])
    perfs[i] = perf
end

# - `sim` cache (10' x 6 N x 4 seeds): 3GB
#     - 95 à 142MB per 10' sim
# - `perf` cache: 0.3MB -- so that could go in git

perfs;

# ## Prepare plot

# We want to plot dots.
# We can either have
# `N = [5, 21]`
# and `TPR_exc = [1 .9 1; .8 .7 .8]` (matrix notation. 3 seeds).
# or
# `N = [5, 5, 5, 21, 21, 21]` (i.e. repeat)
# and `TPR_exc = [1, .9, 1, .8, .7, .8]`.

"""
Create an array of the same shape as the one given, but with just
the values stored under `name` in each element of the given array.
"""
function extract(name::Symbol, arr #=an array of NamedTuples or structs =#)
    getval(index) = getproperty(arr[index], name)
    out = similar(arr, typeof(getval(firstindex(arr))))
    for index in eachindex(arr)
        out[index] = getval(index)
    end
    return out
end;

extract(:TPR_exc, perfs);

import PyPlot

using VoltageToMap.Plot

function make_figure(perfs)
    xticklabels = [p.sim.input.N_conn for p in paramsets[:,1,1]]
    xs = [1:length(xticklabels);]
    fig, ax = plt.subplots()
    plot_detection_rate(rate; kw...) = plot_samples_and_means(xs, rate, ax; kw...)
    plot_detection_rate(extract(:TPR_exc, perfs), label="for excitatory inputs", c=color_exc)
    plot_detection_rate(extract(:TPR_inh, perfs), label="for inhibitory inputs", c=color_inh)
    plot_detection_rate(extract(:FPR, perfs), label="for unconnected spikers", c=color_unconn)

    set(ax; xtype=:categorical, ytype=:fraction, xticklabels, xlabel="Number of connected inputs")

    add_α_line(ax, paramsets[1].evaluation.α)

    l = ax.legend(title="Detection rate", ncol=2, loc="lower right", bbox_to_anchor=(1.06, 1.1))
    l._legend_box.align = "left"
    return fig, ax
end;

# ## Plot

# ### Peak-to-peak

fig, ax = make_figure(perfs[:,:,1]);

# ### Mean

fig, ax = make_figure(perfs[:,:,2]);
