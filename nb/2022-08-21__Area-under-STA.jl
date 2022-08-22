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
#     display_name: Julia 1.7.0
#     language: julia
#     name: julia-1.7
# ---

# # 2022-08-21 • Area under STA (new conntest)

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Params

# Based on Roxin; same as previous nb's.

d = 6
p = get_params(
    duration = 10minutes,
    p_conn = 0.04,
    g_EE = 1   / d,
    g_EI = 18  / d,
    g_IE = 36  / d,
    g_II = 31  / d,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
    record_v = [1, 801],
);

# ## Run sim

s = cached(sim, [p.sim]);

s = augment_simdata(s, p);

# ## New connection test statistic

ii = s.input_info[1];

using PyPlot

using VoltoMapSim.Plot

plotSTA(ii.v, ii.spiketrains.conn.inh[1], p);

sta = calc_STA(ii.v, ii.spiketrains.conn.inh[1], p);

t = sum(sta .- sta[1]);

# What are the units? Sum of: voltage * dt.  
# So units are volt·second. But I'd had to add the dt to every term.
# I can do afterwards.

dt = p.sim.general.Δt;

t * dt / (mV * ms)

# (Estimate from graph for how big this should be: approx 0.5 mV difference, times 40 ms or so.
# So 20 mV·ms. Sure).
# How much is above and below?

sig = (sta .- sta[1]) * dt / (mV*ms)
above = sum(sig[sig .> 0])
below = sum(sig[sig .< 0])
above, below

# Nice, so yes units seem right.

# How to name this measure.
# It's area under STA, referenced to STA at t=0.
# AUS? AUA?
# relsum?  
# Area over start.  
# Just `area` is quite nice.

# Adding this to `misc.jl`:

area(STA) = sum(STA .- STA[1]);

# ## Compare performance
# ..between test measures: existing (peak-to-peak) and the new.

p0 = p;
pn = (@set p.conntest.STA_test_statistic = "area");

cached_conntest_perf = VoltoMapSim.cached_conntest_perf;

perf0 = cached_conntest_perf(1, ii.v, ii.spiketrains, p0);

perf0.detection_rates

perfn = cached_conntest_perf(1, ii.v, ii.spiketrains, pn);

perfn.detection_rates

# Aha! It seems significantly worse than peak-to-peak (for this sim, this neuron).

# Thing left to do is, use this to determine whether a presynaptic neuron is excitatory or inhibitory (now we're cheating and presupposing that knowledge in the conntest perf eval).
#
# I think it's gonna make the performance way worse.

# First, let's redo the test for the inhibitory recorded neuron.

ii_inh = s.input_info[801];

perf0 = cached_conntest_perf(801, ii_inh.v, ii_inh.spiketrains, p0);

perf0.detection_rates

perfn = cached_conntest_perf(801, ii_inh.v, ii_inh.spiketrains, pn);

perfn.detection_rates

# Again, signifcantly worse performance.

# ## Use `area` just for deciding exc or inh

# This was the original motivation for this measure.

# Our current `test_connection` returns a p-value based on peak-to-peak. It only says _whether_ it thinks the presynaptic neuron is connected, not what type it is.
# We'll add the `area` for that:

function test_connection_and_type(v, spikes, p)
    pval = test_connection(v, spikes, p)
    dt = p.sim.general.Δt
    A = area(calc_STA(v, spikes, p)) * dt / (mV*ms)
    if pval ≥ p.evaluation.α
        predicted_type = :unconn
    elseif A > 0
        predicted_type = :exc
    else
        predicted_type = :inh
    end
    return (; predicted_type, pval, area_over_start=A)
end;

test_connection_and_type(ii.v, ii.spiketrains.conn.inh[1], p)

# + [markdown] heading_collapsed=true
# ### Performance optimization sidebar

# + hidden=true
@time test_connection_and_type(ii.v, ii.spiketrains.conn.inh[1], p)

# + [markdown] hidden=true
# Sidenote, shuffle connection test takes a while. Profiling shows that almost all time is spent in the `calc_STA` addition loop.
# ```julia
# STA .+= @view VI_sig[a:b]
# ```
# Doesn't seem much more optimizable.

# + [markdown] hidden=true
# Wait, that broadcasting `.` is not necessary. Let's see what perf is without.

# + hidden=true
@time test_connection_and_type(ii.v, ii.spiketrains.conn.inh[1], p)

# + [markdown] hidden=true
# Huh, perf is worse with it, and way more allocations. Weird. Revert.

# + [markdown] hidden=true
# Trying with manual for loop (and `@inbounds`):

# + [markdown] hidden=true
# [..]
#
# this made a type instability problem apparent (manual loop super slow. → `@code_warntype`. much red. problem was that Δt not inferred (cause simtype abstract). manually adding type made manual loop fast; and the prev, non manual loop also faster :))

# + [markdown] hidden=true
# Yes good, the new profile now also shows that the majority of time is spent in `float:+`, as it should be.

# + [markdown] hidden=true
# Now testing whether sim itself suffers from this same type instability problem..

# + hidden=true
# pshort = (@set p.sim.general.duration = 1*seconds);
# @code_warntype VoltoMapSim.init_sim(pshort.sim);
# state = VoltoMapSim.init_sim(pshort.sim);
#@code_warntype VoltoMapSim.step_sim!(state, pshort.sim, 1);

# + [markdown] hidden=true
# It doesn't. Type known-ness ("stability") seems good enough.

# + [markdown] hidden=true
# ---
# -

# ### Back on topic

# Now use the new `test_connection_and_type` in a reworked `eval_conntest_perf` function:

using DataFrames

function evaluate_conntest_perf_v2(s, m, p)
    # s = augmented simdata
    # m = postsynaptic neuron ID
    ii = s.input_info[m]
    @unpack N_tested_presyn, rngseed = p.evaluation;
    resetrng!(rngseed)
    function get_sample(IDs)
        N = min(length(IDs), N_tested_presyn)
        return sample(IDs, N, replace = false, ordered = true)
    end
    df = DataFrame(
        input_neuron_ID = Int[],     # global ID
        real_type       = Symbol[],  # :unconn, :exc, :inh
        predicted_type  = Symbol[],  # idem
        pval            = Float64[],
        area_over_start = Float64[],
    )
    function test(IDs, real_type)
        for n in get_sample(IDs)
            o = test_connection_and_type(ii.v, s.spike_times[n], p)
            push!(df, Dict(pairs((; input_neuron_ID = n, real_type, o...))))
        end
    end
    test(ii.exc_inputs, :exc)
    test(ii.inh_inputs, :inh)
    test(ii.unconnected_neurons, :unconn)
    #return perf = (; df, detection_rates = (; TPR_exc, TPR_inh, FPR))
    return df
end;

df = evaluate_conntest_perf_v2(s, 1, p);

ENV["LINES"] = 100


