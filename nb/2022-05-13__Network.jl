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

# # 2022-05-13 • A Network

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Params

p = get_params(duration=20*seconds, syn_strengths=LogNormal_with_mean(20 * nS, 1));
# dumps(p)

# ## Run sim

state = (init, var, rec) = sim(p.sim);

import PyPlot

using VoltoMapSim.Plot

spiketimes = []
neuron_nrs = []
for n in eachindex(rec.spike_times)
    spikes = rec.spike_times[n]
    push!(spiketimes, spikes)
    push!(neuron_nrs, fill(n, length(spikes)))
end
fig, ax = plt.subplots(figsize=(4.6, 2.3))
plot(ax, vcat(spiketimes...), vcat(neuron_nrs...), "k.", ms=1.2, clip_on=false,
     ylim=(0, p.sim.network.N),
     xlim=(0, p.sim.general.duration));
N_exc = length(init.neuron_IDs.exc)
N_inh = length(init.neuron_IDs.inh)
set(ax, xlabel="Time (s)", ylabel="Neuron number",
    hylabel="Spike times of $N_exc excitatory, $N_inh inhibitory neurons");

num_spikes = length.(rec.spike_times)
spike_rates = num_spikes ./ p.sim.general.duration
fig, ax = plt.subplots()
M = ceil(Int, maximum(spike_rates))
bins = 0:0.1:M
xlim = (0, M)
ax.hist(spike_rates.exc; bins, label="Excitatory neurons")
ax.hist(spike_rates.inh; bins, label="Inhibitory neurons")
# ax.text(2.2, 80, "Excitatory", c=as_mpl_type(color_exc))
# ax.text(5.2, 30, "Inhibitory", c=as_mpl_type(color_inh))
ax.legend()
ax.set_xlim(0, 1)
set(ax, xlabel="Spike rate (Hz)", ylabel="Number of neurons in bin"; xlim);

# ## A previous sim

spiketimes = []
neuron_nrs = []
for n in eachindex(rec.spike_times)
    spikes = rec.spike_times[n]
    push!(spiketimes, spikes)
    push!(neuron_nrs, fill(n, length(spikes)))
end
fig, ax = plt.subplots(figsize=(4.6, 2.3))
plot(ax, vcat(spiketimes...), vcat(neuron_nrs...), "k.", ms=1.2, clip_on=false, ylim=(0, p.sim.network.N), xlim=(0, p.sim.general.duration));
N_exc = length(init.neuron_IDs.exc)
N_inh = length(init.neuron_IDs.inh)
set(ax, xlabel="Time (s)", ylabel="Neuron number",
    hylabel="Spike times of $N_exc excitatory, $N_inh inhibitory neurons");

median(init.syn_strengths.exc) / nS, median(init.syn_strengths.inh) / nS

num_spikes = length.(rec.spike_times)

spike_rates = num_spikes ./ p.sim.general.duration
[minimum(spike_rates), median(spike_rates), maximum(spike_rates)]' ./ Hz

median(spike_)

VI_sigs = add_VI_noise(state, p.sim, p.imaging);

# ## Plot

t = init.timesteps;

plotsig(t / ms, rec.voltage_traces[1] / mV);

plotsig(t / ms, VI_sigs[1] / mV);

# ## Longer sim, with conntest

p = get_params(duration=3 * minutes);
# dumps(p)

# ## Run sim

@time state = (init, var, rec) = sim(p.sim);
