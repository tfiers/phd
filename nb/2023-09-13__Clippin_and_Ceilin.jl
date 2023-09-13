# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Julia 1.9.3
#     language: julia
#     name: julia-1.9
# ---

# # 2023-09-13 · Clippin and Ceilin

include("lib/Nto1.jl")

# +
N = 6500
duration = 10minutes

@time sim = Nto1AdEx.sim(N, duration, ceil_spikes = false);
# -

# (Hm, spikerate not 4.0 Hz (even though we use our lookup table))

sim.spikerate / Hz

# ## Ceil

V_no_ceil = sim.V;
V_ceil = ceil_spikes!(copy(V_no_ceil), sim.spiketimes);  # V_ceil = Vₛ = 
Nto1AdEx.Vₛ / mV

include("lib/plot.jl")

default_figsize

fig, ax = plt.subplots(figsize=(4, 1.4))
plotsig(V_ceil / mV,    [100, 400], ms, label="Ceiled")
plotsig(V_no_ceil / mV, [100, 400], ms, label="No ceiling")
legend(ax, reverse=false);

# ## Clip

# And now for the clipping, we do it data driven (i.e. no spike detection), just a percentile.

include("lib/df.jl")

set_print_precision(4)
ENV["DATAFRAMES_ROWS"] = 11;

ps = [0, 0.1, 1, 5, 10, 50, 90, 99, 95, 99.9, 99.99, 100]
qs = percentile(V_ceil, ps) / mV
DataFrame(; ps, qs)

# Okay, lesgo for 99.

# +
clip!(V, threshold_percentile = 99) = begin
    V_thr = percentile(V, threshold_percentile)
    V[V .≥ V_thr] .= V_thr
    return V
end

V_ceil_n_clip = clip!(copy(V_ceil));
# -

Vs = [
    (V = V_no_ceil,     label = "No ceiling",       zorder = 2),
    (V = V_ceil,        label = "Ceiled spikes",    zorder = 1),
    (V = V_ceil_n_clip, label = "Ceiled & Clipped", zorder = 3),
];

fig, ax = plt.subplots(figsize=(4, 1.4))
for (V, label, zorder) in Vs
    plotsig(V, [0, 2000], ms; label, zorder, yunit=:mV)
end
hylabel(ax, L"Membrane voltage $V$")
legend(ax);

# ## STAs

exc_input_1 = highest_firing(excitatory_inputs(sim))[1]

fig, ax = plt.subplots()
# set(ax, ylim=[-54.1601, -54.02])  # grr
for (V, label, zorder) in Vs
    STA = calc_STA(V, exc_input_1.times)
    plotSTA(STA; label, nbins_y=4)
end
plt.legend();

# Interesting! They have diff base heights (very convenient for plotting on same ax, here).

# Ok, it makes sense. They're averages: each sample dragged down or up.

# ## ROCs


