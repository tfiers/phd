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
#     display_name: Julia 1.8.1
#     language: julia
#     name: julia-1.8
# ---

# # 2022-09-15 • Two-pass connection test: ptp, then corr with found avg

# Two-pass connection test: peak-to-peak, then correlation with found average

# ## Imports

# +
#
# -

using Revise
import PyPlot

PyPlot.



using MyToolbox

using VoltoMapSim

# ## Params

p = get_params(
    duration = 10minutes,
    p_conn = 0.04,
    g_EE = 1,
    g_EI = 1,
    g_IE = 4,
    g_II = 4,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
    record_v = [1:40; 801:810],
);

# ## Run sim

@time s = cached(sim, [p.sim]);

# (To speed this up (precompile this further): investigate with SnoopCompile or JET. Not now).

s = augment(s, p);

# ## First pass: peak-to-peak

# Let's start with just neuron 1 as postsyn.

m = 1;

perf = cached_conntest_eval(s,m,p);

p.conntest.STA_test_statistic

ENV["LINES"] = 4
perf.tested_neurons

# We take all inputs with `predicted_type` :exc.
#
# Current pval threshold is 0.05.  
# We could be stricter.
#
# It'll be tradeoff: stricter threshold gives less STAs to average to build our template;
# but there will be less noisy STAs mixed in (or even wrong STAs, i.e. of non-inputs).

# +
#= implementation note: 
it's a two stage process, so maybe split dataframe.
namely:

(inputID, postsynID) -> (pval, area_over_start) -> predicted_type

first step depends on 'test statistics' used (ptp, corr-with-some-template).
second step depends on α.

(between first and second data, there's a "-> STA ->" step.
But we don't save that STA in dataframe, too large. it's implicit).

The large work btw is the first step: the shuffles, and for each calculating STA.
So.. we could indeed store these shuffled STAs.. it's just 1000 samples per.
=#
# -

# Now
# - Get the :exc input detections for neuron 1
# - Average their STA
# - Apply this template to STAs of all inputs

# +
# But first: cache STAs :)
# -


