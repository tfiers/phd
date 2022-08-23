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

# ## Use `area` for deciding exc or inh

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

# +
# @cached key=[:m,:p] (
function evaluate_conntest_perf_v2(s, m, p)
    # s = augmented simdata
    # m = postsynaptic neuron ID
    @unpack N_tested_presyn, rngseed = p.evaluation;
    resetrng!(rngseed)
    function get_IDs_labels(IDs, label)
        N = min(length(IDs), N_tested_presyn)
        IDs_sample = sample(IDs, N, replace = false, ordered = true)
        return zip(IDs_sample, fill(label, N))
    end
    ii = s.input_info[m]
    IDs_labels = chain(
        get_IDs_labels(ii.exc_inputs, :exc),
        get_IDs_labels(ii.inh_inputs, :inh),
        get_IDs_labels(ii.unconnected_neurons, :unconn),
    )
    tested_neurons = DataFrame(
        input_neuron_ID = Int[],     # global ID
        real_type       = Symbol[],  # :unconn, :exc, :inh
        predicted_type  = Symbol[],  # idem
        pval            = Float64[],
        area_over_start = Float64[],
    )
    @showprogress (every = 400ms) "Testing connections: " (
    for (n, label) in collect(IDs_labels)  # `collect` necessary somehow
        test_result = test_connection_and_type(ii.v, s.spike_times[n], p)
        row = (input_neuron_ID = n, real_type = label, test_result...)
        push!(tested_neurons, Dict(pairs(row)))
    end)
    tn = tested_neurons
    det_rate(t) = count((tn.real_type .== t) .& (tn.predicted_type .== t)) / count(tn.real_type .== t)    
    detection_rates = (
        TPR_exc = det_rate(:exc),
        TPR_inh = det_rate(:inh),
        FPR = 1 - det_rate(:unconn),
    )
    return (; tested_neurons, detection_rates)
end
# end)

cached_eval(s, m, p) = cached(evaluate_conntest_perf_v2, [s, m, p], key = [m, p]);
# -

# Aside: @cached macro wish.  
# Also generates a $(funcname)_uncached.
# So here: evaluate_conntest_perf_uncached

# +
# @profview evaluate_conntest_perf_v2(s, 1, p);
# -

# ^ Most time spent in the `+` and the `setindex` of the `calc_STA` loop.
# (A bit also in `shuffle_ISIs`).
# (Could speed up a bit maybe by having STA on the stack -- prob using StaticArrays.jl -- to save that `setindex` time.
# Though wouldn't be major, as most time is still spent in float `+`). Another thing to try is `@fastmath` IEEE rules relaxing, to speed up the `+`.

testeval = cached_eval(s, 1, p);

ENV["LINES"] = 100

testeval.detection_rates

# Comparison with before, when we didn't predict the type (just connected or not) (from `2022-07-05__Network-conntest`):
#
# (TPR_exc = 0.154, TPR_inh = 1, FPR = 0.15)

# The exc performance drops to zero.
# This is because all previously detected exc inputs are still detected, but classified as inhibitory, as seen in the below table.
#
# The FPR rate is different because we now take a random sample of unconnected neurons to test (before, we took the first 40).

testeval.tested_neurons

# ### Inhibitory postsynaptic neuron

# Now test input connections to the recorded inhibitory neuron:

te_inh = cached_eval(s, 801, p);

te_inh.detection_rates

# Comparison with before, as above:
#
# `(TPR_exc = 0.714, TPR_inh = 0.9, FPR = 0.05)`

# Results per neuron below.
# The `area_over_start` seems to work: exc is mostly positive (and thus predicted as exc), and vice versa for inhibitory/negative.

te_inh.tested_neurons

# We missclassify an inhibitory input as excitatory because it's "area over start" is positive.
# What does the STA look like?

plotSTA(s.signals[801].v, s.spike_times[846], p);

# Looks nicely downwards..

area(calc_STA(s.signals[801].v, s.spike_times[846], p))

# But the area-over-start is indeed positive.
#
# Could be remedied with a shorter STA window length.

# For comparison, the STA of a correctly identified inh input:

plotSTA(s.signals[801].v, s.spike_times[815], p);

# Looks very similar (the relative height of the positive and negative bumps).
#
# The problem (the difference) is at t0.

# ---
# Unrelated question (on previous results):
# Why are exc input STA's on inh good, but on exc neurons so bad?


