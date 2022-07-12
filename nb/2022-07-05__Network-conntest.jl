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

# # 2022-07-05 • Network conntest Roxin params

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Params

# Based on Roxin (see previous nb).

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
    to_record = [1, 801],
);
# dumps(p)

# ## Run sim

s = cached(sim, [p.sim]);

# Uncached output:
# ```
# Running simulation: 100%|███████████████████████████████| Time: 0:11:31
# Saving output at `C:\Users\tfiers\.phdcache\datamodel v2 (net)\sim\b77ff1c19d7f1e33.jld2` … done (0.7 s)
# ```

function augment_simdata(s, p)
    num_spikes_per_neuron = length.(s.spike_times)
    spike_rates           = num_spikes_per_neuron ./ p.sim.general.duration
    return (; s..., num_spikes_per_neuron, spike_rates)
end;

s = augment_simdata(s,p);

import PyPlot

using VoltoMapSim.Plot

tlim = @. 3minutes + [0,10]seconds;
tlim = [0,10]seconds;

rasterplot(s.spike_times; tlim);

histplot_fr(s.spike_rates);

# +
# VI_sigs = add_VI_noise(s.voltage_traces, p);

# +
# ax = plotsig(s.timesteps, VI_sigs[1] / mV; tlim, label="VI signal");
# ax = plotsig(s.timesteps, s.signals[1] / mV; tlim, ax, label="Membrane voltage")
# legend(ax, reorder=[2=>1])
# set(ax, xlabel="Simulation time (s)", ylabel="mV");
# -

# ## Connection test

analyzed_neuron = 1;  # neuron ID

v = s.signals[analyzed_neuron].v;

input_neurons = s.input_neurons[analyzed_neuron]
length(input_neurons)

input_neurons_by_type = CVec(exc=[n for n in input_neurons if s.neuron_type[n] == :exc],
                             inh=[n for n in input_neurons if s.neuron_type[n] == :inh])

length(input_neurons_by_type.exc),
length(input_neurons_by_type.inh)

unconnected_neurons = [n for n in s.neuron_IDs if n ∉ input_neurons && n != analyzed_neuron];
length(unconnected_neurons)

# Highest firing inputs

sort!(collect(zip(input_neurons, s.spike_rates[input_neurons])), by = tup -> tup[2])

highest_firing_inputs = sort(input_neurons, by = id -> s.spike_rates[id], rev = true);
highest_firing_inputs[1]

plotSTA(v, s.spike_times[highest_firing_inputs[1]], p);

highest_firing_exc_inputs = [n for n in highest_firing_inputs if s.neuron_type[n] == :exc]
highest_firing_inh_inputs = [n for n in highest_firing_inputs if s.neuron_type[n] == :inh]
highest_firing_exc_inputs[1], highest_firing_inh_inputs[1]

plotSTA(v, s.spike_times[highest_firing_exc_inputs[1]], p);

plotSTA(v, s.spike_times[highest_firing_inh_inputs[2]], p);

# I→E STAs are much cleaner. This is likely bc their synaptic weights are 36x larger.

spiketrains_by_type = (;
    conn = (;
        exc = [s.spike_times[n] for n in input_neurons_by_type.exc],
        inh = [s.spike_times[n] for n in input_neurons_by_type.inh],
    ),
    unconn = [s.spike_times[n] for n in unconnected_neurons],
);

perf = evaluate_conntest_perf(v, spiketrains_by_type, p);

# (see bottom of notebook)

# All inhibitory detected! :D

# This is cause I changed reversal potential from -65 to -80 mV; and cause 36x stronger synapses (both following Roxin).

# ----

# Check whether detected exc inputs are the highest firing ones.

fr = Float64[]
pval = Float64[]
for (i,n) in enumerate(input_neurons_by_type.exc)
    push!(fr, spike_rates[n])
    push!(pval, perf.p_values.conn.exc[i])
end
ax = plot(fr, pval, "k.", clip_on = false, xlabel="Firing rate (Hz)", ylabel="p-value conntest", ylim=(0,1));

# No, doesn't seem like it.

# Plot STA of detected exc inputs.

show(perf.p_values.conn.exc)

N = length(input_neurons_by_type.exc)
for i in sortperm(perf.p_values.conn.exc)[[1,2,N-1,N]]
    plotSTA(v, s.spike_times[input_neurons_by_type.exc[i]], p)
end

# blue and orange are the two lowest p-values, green and red the highest (worst, undetected).

# ## Test connections to an inhibitory neuron

function neuron_info(n, s, p)
    # Return exc and inh inputs, sorted so the highest firing are first.
    # n = neuron ID
    # s = augmented simdata
    # p = ExperimentParams
    input_neurons = sort(s.input_neurons[n], by = m -> s.spike_rates[m], rev = true)
    exc_inputs = [m for m in input_neurons if s.neuron_type[m] == :exc]
    inh_inputs = [m for m in input_neurons if s.neuron_type[m] == :inh]
    unconnected_neurons = [m for m in s.neuron_IDs if m ∉ input_neurons]
    spiketrains = (
        conn = (
            exc = [s.spike_times[m] for m in exc_inputs],
            inh = [s.spike_times[m] for m in inh_inputs],
        ),
        unconn = [s.spike_times[m] for m in unconnected_neurons],
    )
    return (;
        exc_inputs,
        inh_inputs,
        unconnected_neurons,
        spiketrains,
        v = s.signals[n].v,
        num_inputs = (exc = length(exc_inputs), inh = length(inh_inputs)),
    )
end;
ni = neuron_info(801, s, p);

ni.num_inputs

ax1 = plotSTA(ni.v, ni.spiketrains.conn.exc[1], p);
ylim = ax1.get_ylim()
plotSTA(ni.v, ni.spiketrains.conn.exc[2], p; ylim);
plotSTA(ni.v, ni.spiketrains.conn.exc[3], p; ylim);
plotSTA(ni.v, ni.spiketrains.conn.exc[end], p; ylim);

ax1 = plotSTA(ni.v, ni.spiketrains.conn.inh[1], p);
ax2 = plotSTA(ni.v, ni.spiketrains.conn.inh[2], p);

perf = evaluate_conntest_perf(ni.v, ni.spiketrains, p);

perf.detection_rates

# 15/21 exc inputs detected, 9/10 inh.  
# 2/40 tested unconnected.

# ### Use `neuron_info` for neuron 1

ni1 = neuron_info(1, s, p);

ni1.num_inputs

for i in 1:2
    plotSTA(ni1.v, ni1.spiketrains.conn.exc[i], p)
end

ax1 = plotSTA(ni1.v, ni1.spiketrains.conn.inh[3], p);
ylim = ax1.get_ylim()
plotSTA(ni1.v, ni1.spiketrains.conn.inh[1], p; ylim);
plotSTA(ni1.v, ni1.spiketrains.conn.inh[2], p; ylim);
plotSTA(ni1.v, ni1.spiketrains.conn.inh[end], p; ylim);

perf = evaluate_conntest_perf(ni1.v, ni1.spiketrains, p);

perf.detection_rates
