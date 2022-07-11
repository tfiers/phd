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

# # 2022-07-01 • g_EI

# Playing with the between-group synaptic strengths and their effect on firing rate distributions.

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Sim

import PyPlot

using VoltoMapSim.Plot

function sim_and_plot(; params...)
    p = get_params(; params...)
    s = cached(sim, [p.sim])
    num_spikes = length.(s.spike_times)
    sum(num_spikes) > 0 || error("no spikes")
    spike_rates = num_spikes ./ p.sim.general.duration
    histplot_fr(spike_rates)
    rasterplot(s.spike_times, tlim=[0,10]seconds)
    return p, s, spike_rates
end;

# ## 4:1

sim_and_plot(
    duration = 20seconds,
    g_EE = 1,
    g_EI = 1,
    g_IE = 4,
    g_II = 4,
);
# Default values

d = 2  # to lower firing rate
sim_and_plot(
    duration = 20seconds,
    g_EE = 1 / d,
    g_EI = 4 / d,
    g_IE = 1 / d,
    g_II = 4 / d,
);
# Previous, wrong values

# Aggregated over E and I, you can indeed be fooled that the fr histogram is lognormal.

# ## Roxin2011

d = 6
p, s, spike_rates = sim_and_plot(
    duration = 10seconds,
    g_EE = 1   / d,
    g_EI = 18  / d,
    g_IE = 36  / d,
    g_II = 31  / d,
);
# Roxin2011 values

# Recreating plots from roxin.  
# Here: aggregate spike rates of inh and exc, on log scale

bins = exp10.(-1:0.2:1)
fig, ax = plt.subplots()
ax.hist(spike_rates; bins, histtype="step")
set(ax, xscale="log", xlabel="Firing rate (Hz)", xlim=(0.1,10));

# Note that Roxin firing rates have much wider range: from 0.01 to 100

fig, ax = plt.subplots(figsize=(8,1.3))
plotsig(s.timesteps / ms, s.voltage_traces[1] / mV; ax, tlim=[0,1000], xlabel="Time (ms)");

# ## No lognormal weights

# Roxin2011 finds that wider synaptic strength distribution gives __narrower__ firing rate distribution.
# So let's do as they do in most plots, and give no variance at all to the synaptic weights.

d = 6
p, s, spike_rates = sim_and_plot(
    duration = 20seconds,
    g_EE = 1   / d,
    g_EI = 18  / d,
    g_IE = 36  / d,
    g_II = 31  / d,
    syn_strengths = LogNormal_with_mean(20nS, 0)  # ← zero variance
);
# Roxin2011 values

# Result: nope. Not wider

# ## Positive-mean input current

# Positive as in: excitatory. (Previous defaults had zero-mean input current. But Roxin had positive mean; dV/dt ~ +I_ext in their eq. In our eq, dV/dt ~ –I_ext).

# Also, they have lower p_conn than our default of 10%. (Result after changing this: not much difference)

1/√.1ms

d = 6
p, s, spike_rates = sim_and_plot(
    duration = 3seconds,
    p_conn = 0.04,
    g_EE = 1   / d,
    g_EI = 18  / d,
    g_IE = 36  / d,
    g_II = 31  / d,
    ext_current = Normal(-0.42 * pA/√seconds, 4 * pA/√seconds),
);
# Roxin2011 values

# The longer you simulate, the narrower both distributions seem to become.  
#
# So I could see obtaining the approximate results of Roxin2011 figure 8:
# - simulate for a short time  (they did not report their simulation time. But given that they have 2000x the number of neurons as us here, it can't have been very long).
# - give the inhibitory neurons less external current (which is indeed what they did): their distribution will then overlap more with the excitatory one
# - plot the firing rates in aggregate (not separate as I did here).

# ## Shape of normal on log scale

x = 1:0.01:10
y = @. exp(-(x-5)^2 / 3)
fig,ax = plt.subplots()
ax.plot(x,y);
set(ax, xscale="log");

# Looks like the "very close to lognormal" plots in roxin.

# ## Truncated normal is 'heavy tailed'

# Fig 5C of Roxin

distr = TruncatedNormal(1Hz, 7Hz, 0Hz, Inf*Hz)  # mean, std, left bound, right bound
fr = rand(distr, 12500)
plt.hist(fr, bins=30, ec="k", fc="w")
plt.plot(mean(fr), -50, "w^", clip_on=false, mec="k", ms=8)
plt.plot(median(fr), -50, "k^", clip_on=false, mec="k", ms=8)
plt.ylim(bottom=0)
plt.xlim(0, 40);

median(fr), mean(fr)

# tbf Roxin had a bit larger diff between these.

# ## Sum of two normals

distr = truncated(MixtureModel(Normal, [(2Hz,5Hz), (8Hz,6Hz)], [0.8, 0.2]), lower=0Hz)
fr = rand(distr, 10_000)
plt.hist(fr, bins=20, ec="k", fc="w");

# log scale:

bins = exp10.(-1:0.2:3)
fig, ax = plt.subplots()
ax.hist(fr; bins, histtype="step")
set(ax, xscale="log", xlim=(0.1,100));

# Looks very much like fig 8D.

# ## Sanity check

p, s, spike_rates = sim_and_plot(
    duration = 3seconds,
    g_EE = 0,
    g_EI = 0,
    g_IE = 600,
    g_II = 0,
    to_record = [696],
);

s.spike_times[812] / ms .+ 10

s.spike_times[696] / ms

v,u,g_exc,g_inh = s.signals[696];

@unpack E_exc, E_inh = p.sim.general.synapses
I = @. (  g_exc * (v - E_exc)
        + g_inh * (v - E_inh));

plotsig(s.timesteps / ms, (v .- E_inh) / mV, tlim=[1021,1022], marker=".", linestyle="None");

plotsig(s.timesteps / ms, I / nA, tlim=[1021,1022], marker=".", linestyle="None");

plotsig(s.timesteps / ms, s.signals[696].v / mV, tlim=[1021,1022], marker=".", linestyle="None");

plotsig(s.timesteps, s.signals[696].v / mV, tlim=[1.021,1.022]);

plotsig(s.timesteps, s.signals[696].v / mV, tlim=[1.02,1.04])

plotsig(s.timesteps, s.signals[696].u / pA, tlim=[1.02,1.04]);

plotsig(s.timesteps, s.signals[696].g_inh / nS, tlim=[1.02,1.04]);

numspikes = length.(s.spike_times)

findmax(numspikes)  # (val, index)

s.spike_times[696] / ms

# Clusters, these always start a bit more than 10 ms (tx delay) after the input spikes of 812.
# (found by printing spiketimes of all 696's inputs)

s.spike_times[812] / ms

labels(s.neuron_IDs)[812]

# I wanna know if syn between these two is particularly strong.

[syn for syn in s.output_synapses[812] if s.postsyn_neuron[syn] == 696]

s.syn_strengths[69244] / nS

sort(s.syn_strengths[s.syns.inh_to_exc] / nS)

# So our man has the second highest synaptic strength.

plt.hist(length.(values(s.input_neurons)));

# ## More sanity check

p, s, spike_rates = sim_and_plot(
    duration = 3seconds,
    g_EE = 0,
    g_EI = 4,
    g_IE = 0,
    g_II = 0,
);

p, s, spike_rates = sim_and_plot(
    duration = 3seconds,
    g_EE = 1,
    g_EI = 0,
    g_IE = 0,
    g_II = 0,
);

p, s, spike_rates = sim_and_plot(
    duration = 3seconds,
    g_EE = 0,
    g_EI = 0,
    g_IE = 0,
    g_II = 400,
);

# ## Params to do conntest with

plotsig(s.timesteps, s.signals[1].v)

d = 8
p, s, spike_rates = sim_and_plot(
    duration = 30seconds,
    p_conn = 0.04,
    g_EE = 1   / d,
    g_EI = 18  / d,
    g_IE = 36  / d,
    g_II = 31  / d,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
);
# This is based on above, "pos mean input current" & roxin

# Distributions same width if 3 or 30 seconds. good.

d = 6
p, s, spike_rates = sim_and_plot(
    duration = 3seconds,
    p_conn = 0.04,
    g_EE = 1   / d,
    g_EI = 18  / d,
    g_IE = 36  / d,
    g_II = 31  / d,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
);
# This is based on above, "pos mean input current" & roxin

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
s = cached(sim, [p.sim]);


