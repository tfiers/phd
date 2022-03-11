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
#     display_name: Julia 1.7.1
#     language: julia
#     name: julia-1.7
# ---

# # 2022-03-02 • Factor out conntest & eval code

# ## Setup

# +
#
# -

using Revise

using MyToolbox

using VoltageToMap

# ## Params & sim


# Short warm-up run. Get compilation out of the way.

p0 = ExperimentParams(
    sim = SimParams(
        input = previous_N_30_input,
        duration = 1 * minutes
    )
);

@time sim(p0.sim);

p = ExperimentParams(
    sim = SimParams(
        input = realistic_N_6600_input,
        duration = 0.2 * minutes,
        synapses = SynapseParams(
            Δg_multiplier = 0.066,
        ),
    )
);
dumps(p)

t, v, vimsig, input_spikes = @time sim(p.sim);

num_spikes = length.(input_spikes)

# ## Plot

import PyPlot

using VoltageToMap.Plot

tzoom = [200, 1200]ms
ax = plotsig(t, vimsig / mV, tzoom; xlabel="Time (s)", hylabel="mV", alpha=0.7);
plotsig(t, v / mV, tzoom; ax);

# ## Test conntest

example_presynspikes = input_spikes.conn.exc[44]
plotSTA(vimsig, example_presynspikes, p);

p_value = test_connection(vimsig, example_presynspikes, p)

# ## Performance



# ## Results

resetrng!(20220222);

# +
num_trains = 40
println("Average p(shuffled trains with higher STA mean).")
println("(N = $(num_trains) input spike trains per category)")

p_exc    = Float64[]
p_inh    = Float64[]
p_unconn = Float64[]

for (groupname, spiketrains, pvals) in (
        ("excitatory",    input_spikes.conn.exc, p_exc),
        ("inhibitory",    input_spikes.conn.inh, p_inh),
        ("unconnected",   input_spikes.unconn, p_unconn),
    )
    for spiketrain in spiketrains[1:num_trains]
        push!(pvals, test_connection(spiketrain))
        print("."); flush(stdout)
    end
    @printf "%12s: %.3g\n" groupname mean(pvals)
end
# -

fig, ax = plt.subplots(figsize=(3.4,3))
function plotdot(y, x, c, jitter=0.28)
    N = length(y)
    x -= 0.35
    plot(x*ones(N) + (rand(N).-0.5)*jitter, y, "o", color=c, ms=4.2, markerfacecolor="none", clip_on=false)
    plot(x+0.35, mean(y), "k.", ms=10)
end
plotdot(p_exc,    1, "C2"); ax.text(1-0.16, -0.1, "excitatory"; color="C2", ha="center")
plotdot(p_unconn, 2, "C0"); ax.text(2-0.16, -0.1, "unconnected"; color="C0", ha="center")
plotdot(p_inh,    3, "C1"); ax.text(3-0.16, -0.1, "inhibitory"; color="C1", ha="center")
ax.boxplot([p_exc, p_unconn, p_inh], widths=0.2, medianprops=Dict("color"=>"black"))
set(ax, xlim=(0.33, 3.3), ylim=(0, 1), xaxis=:off)
hylabel(ax, L"p(\, \mathrm{shuffled\ \overline{STA}} \ > \ \mathrm{actual\ \overline{STA}}\, )"; dy=10);

# Proportion of shuffled spike trains for which `mean(STA)` is higher than the unshuffled spike train.
#
# Excitatory (green), unconnected (blue), and inhibitory (orange) input neurons.
#
#
# 10-minute simulation with a total of 6500 connected input neurons.
