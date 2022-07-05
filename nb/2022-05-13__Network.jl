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

p = get_params(duration=10*minutes);
# dumps(p)

# ## Run sim

s = cached(sim, [p.sim]);

# Uncached output:
# ```
# Running simulation: 100%|███████████████████████████████| Time: 0:05:46
# Saving output at `C:\Users\tfiers\.phdcache\datamodel v2 (net)\sim\24d9de18b7c371f6.jld2` … done (15.2 s)
# ```

import PyPlot

using VoltoMapSim.Plot

tlim = @. 3minutes + [0,10]seconds;
tlim = [0,10]seconds;

rasterplot(s.spike_times; tlim);

num_spikes = length.(s.spike_times)
spike_rates = num_spikes ./ p.sim.general.duration
fig, ax = plt.subplots()
M = round(Int, maximum(spike_rates))
bins = 0:0.1:M
xlim = (0, M)
ax.hist(spike_rates.exc; bins, label="Excitatory neurons")
ax.hist(spike_rates.inh; bins, label="Inhibitory neurons")
# ax.text(2.2, 80, "Excitatory", c=as_mpl_type(color_exc))
# ax.text(5.2, 30, "Inhibitory", c=as_mpl_type(color_inh))
ax.legend()
set(ax, xlabel="Spike rate (Hz)", ylabel="Number of neurons in bin"; xlim);

VI_sigs = add_VI_noise(s.voltage_traces, p);

ax = plotsig(s.timesteps, VI_sigs[1] / mV; tlim, label="VI signal");
ax = plotsig(s.timesteps, s.voltage_traces[1] / mV; tlim, ax, label="Membrane voltage")
legend(ax, reorder=[2=>1])
set(ax, xlabel="Simulation time (s)", ylabel="mV");

# ## Connection test

trace_ID = 1
VI_sig = VI_sigs[trace_ID];
v = s.voltage_traces[trace_ID];

analyzed_neuron = s.recorded_neurons[trace_ID]  # neuron ID

input_neurons = s.input_neurons[analyzed_neuron]
length(input_neurons)

input_neurons_by_type = CVec(exc=[n for n in input_neurons if s.neuron_type[n] == :exc],
                             inh=[n for n in input_neurons if s.neuron_type[n] == :inh])

length(input_neurons_by_type.exc),
length(input_neurons_by_type.inh)

unconnected_neurons = [n for n in s.neuron_IDs if n ∉ input_neurons && n != analyzed_neuron];
length(unconnected_neurons)

# Calc and plot STA of some excitatory inputs (first row) and inhibitory inputs (second row).

function plot_some_STAs()
    (nrows, ncols) = (2, 5)
    fig, axs = plt.subplots(; nrows, ncols, figsize=(9, 2.2), sharex=true, sharey=true)
    exc = sample(input_neurons_by_type.exc, ncols, replace=false)
    inh = sample(input_neurons_by_type.inh, ncols, replace=false)
    names = labels(s.neuron_IDs)
    for r in 1:nrows
        for c in 1:ncols
            ax = axs[r, c]
            n = (r == 1) ? exc[c] : inh[c]
            plotSTA(v, s.spike_times[n], p; ax, xlabel=nothing, hylabel=(names[n], :dy=>-10, :loc=>:right))
            ax.hylabel.set_fontsize("x-small")
            ax.hylabel.set_color(as_mpl_type(Gray(0.2)))
        end
    end
    set(axs[nrows,1], xlabel="Time after spike (ms)", ylabel="STA (mV)")
end
plot_some_STAs()

plot_some_STAs()

spiketrains_by_type = (;
    conn = (;
        exc = [s.spike_times[n] for n in input_neurons_by_type.exc],
        inh = [s.spike_times[n] for n in input_neurons_by_type.inh],
    ),
    unconn = [s.spike_times[n] for n in unconnected_neurons],
);

perf = evaluate_conntest_perf(v, spiketrains_by_type, p)


