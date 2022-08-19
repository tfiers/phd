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

# # 2022-08-17 • Investigate correlated spikers

# Cors between inputs and unconnected:
# - split between inh and exc inputs
# - why those few ouliers with high cor?

# Also basic test: only 40 unconnected tested, so only 2 needed for FPR of 5%. So test with more to exclude low-N effect.

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

# ## Sanity check for high FPR: test more unconnected

p2 = @set p.evaluation.N_tested_presyn = 200;

# 200 instead of 40, that's 5x.
# And it's 1/5th of all 1000 neurons.

m = 1;

v = s.signals[m].v
ii = get_input_info(m, s, p2);
ii.num_inputs

perf2 = cached(evaluate_conntest_perf, [v, ii.spiketrains, p2], key = [p2, m]);

perf2.detection_rates

count(perf2.p_values.unconn .< 0.05)

26/200

10/200

# So yes, we still have the higher-than-α FPR. It's not a small N effect: FP = 26 vs the expected 10 of α = 5%.

# ## Bin & cor spiketrains again

# Re-run conntests but only for 40 tested (too much cors otherwise).

perf = cached(evaluate_conntest_perf, [v, ii.spiketrains, p], key = [p, m]);

v = s.signals[m].v
ii = get_input_info(m, s, p);
ii.num_inputs

# Split unconnected by their connection test significance:

signif_unconn = ii.unconnected_neurons[findall(perf.p_values.unconn .< p.evaluation.α)];
tested_unconn = ii.unconnected_neurons[1:p.evaluation.N_tested_presyn]
insignif_unconn = [n for n in tested_unconn if n ∉ signif_unconn];

length(signif_unconn), length(tested_unconn)

# Now bin spiketrains..

binned_spikes = [bin(s.spike_times[n], duration = 10minutes, binsize = 100ms) for n in s.neuron_IDs];

# ..and correlate unconnected with connected.

# We have four combo's: {FP, TN} x {exc inputs, inh inputs}

spikecors(group_A, group_B) = vec([cor(binned_spikes[m], binned_spikes[n]) for m in group_A, n in group_B]);

# ### Plot

using PyPlot

using VoltoMapSim.Plot

jn(strs...) = join(strs, "\n");

function corplot(; binsize)
    binned_spikes = [bin(s.spike_times[n], duration = 10minutes; binsize) for n in s.neuron_IDs];
    spikecors(group_A, group_B) = vec([cor(binned_spikes[m], binned_spikes[n]) for m in group_A, n in group_B]);
    ax = ydistplot(
        jn("Unconnected,", "not detected", "↕", "exc inputs") => spikecors(insignif_unconn, ii.exc_inputs),
        jn("Unconnected,", "not detected", "↕", "inh inputs") => spikecors(insignif_unconn, ii.inh_inputs),
        jn("Unconnected", "but detected (FP)", "↕", "exc inputs") => spikecors(signif_unconn, ii.exc_inputs),
        jn("Unconnected", "but detected (FP)", "↕", "inh inputs") => spikecors(signif_unconn, ii.inh_inputs),
        figsize = (6, 3),
        hylabel = jn("Spike correlations between unconnected & connected neurons, for neuron $m",
                     "(Binsize = $(binsize/ms) ms)"),
        ylabel = "Pearson correlation of binned spikes",
    )
    add_refline(ax, 0, zorder=1, c="gray")
    return ax
end
ax = corplot(binsize=100ms);

# So the strong-correlation outliers are with inhibitory inputs.

# And the (slightly) higher correlation seems to be for inh inputs, not exc.
#
# But we must zoom in a bit:

set(ax, ylim=(-0.08, 0.08), xtype=:keep)
ax.figure

# We expected the FP correlations with exc to be higher.
# But it's higher with inh.
# That makes sense though as the inh→exc connections were better detected than the exc→exc. (neuron `1` is exc).

# + [markdown] heading_collapsed=true
# ### Other binsizes

# + hidden=true
corplot(binsize=200ms);

# + hidden=true
corplot(binsize=50ms);

# + hidden=true
corplot(binsize=25ms);

# + hidden=true
corplot(binsize=10ms);

# + hidden=true
corplot(binsize=5ms);

# + [markdown] hidden=true
# So the outliers remain for binsizes 50 and 200, and the FP ↔ inh nonzero corr seems to too.
# For binsize 25 ms however, both phenomena disappear; but then for 10 and 5 ms, the nonzero corr seems to be back.
# -

# ## All spike correlations in network

# We need to sample, as calculating 1000x1000 spiketrain correlations takes too long.

ns = sample(s.neuron_IDs, 100, replace=false);

spikecors_nosame(A,B) = vec([cor(binned_spikes[m], binned_spikes[n]) for m in A, n in B if m != n]);

ydistplot(""=>spikecors_nosame(ns,ns), ref=0, hylabel=jn("Spike correlations of random neuron sample", "(Binsize 100 ms)"));

# So the 0.15 to 0.35 outliers we saw are in fact rare.

# Split by neuron types

ns_exc = [m for m in ns if m in s.neuron_IDs.exc]
ns_inh = [m for m in ns if m in s.neuron_IDs.inh];

ydistplot(
    "exc ↔ exc" => spikecors_nosame(ns_exc, ns_exc),
    "exc ↔ inh" => spikecors_nosame(ns_exc, ns_inh),
    "inh ↔ inh" => spikecors_nosame(ns_inh, ns_inh),
    ref=0,
    hylabel=jn("Spike correlations of random neuron sample", "(Binsize 100 ms)")
);

# inhibitory neurons seem on average to be more correlated with other neurons than excitatory neurons are.

# ## Investigate outliers

# What do their STA's and spiketrains look like?  
# How are they connected in network?  
# Why does that one have high cor but is still undetected?


