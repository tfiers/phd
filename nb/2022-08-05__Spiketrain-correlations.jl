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

# # 2022-08-05 • Spiketrain correlations (of unconnected-but-detected)

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

# ## Bin spiketrains

function bin(spiketimes; duration, binsize)
    # `spiketimes` is assumed sorted.
    # `duration` is of the spiketimes signal and determines the number of bins.
    num_bins = ceil(Int, duration / binsize)
    spikecounts = fill(0, num_bins)
    # loop counters:
    spike = 1
    bin_end_time = binsize
    for bin in 1:num_bins
        while spiketimes[spike] < bin_end_time
            spikecounts[bin] += 1
            spike += 1
            if spike > length(spiketimes)
                return spikecounts
            end
        end
        bin_end_time += binsize
    end
end;

# ### Test

events = s.spike_times[1][1:10]
show(events)

show(bin(events; duration=20, binsize=2))

# Looks good

# ### Apply

p.conntest.STA_window_length / ms

binned_spikes = [bin(s.spike_times[n], duration = 10minutes, binsize = 100ms) for n in s.neuron_IDs];

# ## Correlation with recorded neuron

m = 1;  # analyzed neuron

cors = [cor(binned_spikes[m], binned_spikes[n]) for n in s.neuron_IDs];  # Pearson corr

# ## Split neurons by type

v = s.signals[m].v
ii = get_input_info(m, s, p);
ii.num_inputs

perf = cached(evaluate_conntest_perf, [v, ii.spiketrains, p], key = [p, m]);

perf.detection_rates

signif_unconn = ii.unconnected_neurons[findall(perf.p_values.unconn .< p.evaluation.α)];
tested_unconn = ii.unconnected_neurons[1:p.evaluation.N_tested_presyn]
insignif_unconn = [n for n in tested_unconn if n ∉ signif_unconn];

length(signif_unconn), length(insignif_unconn)

# ## Plot

using PyPlot

using VoltoMapSim.Plot

Plot.add_refline

function plotcors(cors, binsize_ms)
    ax = ydistplot(
        "Exc inputs" => cors[ii.exc_inputs],
        "Inh inputs" => cors[ii.inh_inputs],
        "Unconnected\nbut detected" => cors[signif_unconn],
        "Unconnected,\nnot detected" => cors[insignif_unconn],
        figsize = (6, 3),
        hylabel = "Binned spiketrain correlations to neuron $m  (binsize = $(binsize_ms) ms)",
        ylabel = "Pearson correlation",
        # ylim = [-0.04, +0.045],
    )
    Plot.add_refline(ax, 0, zorder=1, c="gray")
end
plotcors(cors, 100);

# ## More bin sizes

function plotcors_for(; binsize)
    binned_spikes = [bin(s.spike_times[n], duration = 10minutes; binsize) for n in s.neuron_IDs]
    cors = [cor(binned_spikes[m], binned_spikes[n]) for n in s.neuron_IDs]
    plotcors(cors, binsize/ms)
end;

for binsize in [12.5, 25, 50, 100, 200] * ms
    plotcors_for(; binsize)
end;


