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

p0 = params
p0 = @set p0.sim.input    = previous_N_30_input
p0 = @set p0.sim.duration = 1 * minutes;

@time sim(p0.sim);

p = params
p = @set p.sim.input                  = realistic_N_6600_input
p = @set p.sim.duration               = 10 * minutes
p = @set p.sim.synapses.Δg_multiplier = 0.08
dumps(p)

t, v, input_spikes = @time sim(p.sim);

num_spikes = length.(input_spikes)

# ## Plot

import PyPlot

using Sciplotlib

""" tzoom = [200ms, 600ms] e.g. """
function plotsig(t, sig, tzoom = nothing; ax = nothing, clip_on=false, kw...)
    isnothing(tzoom) && (tzoom = t[[1, end]])
    izoom = first(tzoom) .≤ t .≤ last(tzoom)
    if isnothing(ax)
        plot(t[izoom], sig[izoom]; clip_on, kw...)
    else
        plot(t[izoom], sig[izoom], ax; clip_on, kw...)
    end
end;

plotsig(t, v/mV, [0s, 4seconds], xlabel="Time (s)", hylabel="mV");

# ## Imaging noise

# +
izh_params = cortical_RS

imaging_spike_SNR  #=::Float64=#  = 20
spike_height       #=::Float64=#  = izh_params.v_peak - izh_params.vr
σ_noise            #=::Float64=#  = spike_height / imaging_spike_SNR;
# -

noise = randn(length(v)) * σ_noise
vimsig = v + noise;

ax = plotsig(t, vimsig / mV, [200ms,1200ms], xlabel="Time (s)", hylabel="mV", alpha=0.7);
plotsig(t, v / mV, [200ms,1200ms], xlabel="Time (s)", hylabel="mV"; ax);

# ## Window

window_duration    #=::Float64=#  = 100 * ms;

# +
const Δt = p.Δt
const win_size = round(Int, window_duration / Δt)
const t_win = linspace(zero(window_duration), window_duration, win_size)

function calc_STA(presynaptic_spikes)
    STA = zeros(eltype(vimsig), win_size)
    win_starts = round.(Int, presynaptic_spikes / Δt)
    num_wins = 0
    for a in win_starts
        b = a + win_size - 1
        if b ≤ lastindex(vimsig)
            STA .+= @view vimsig[a:b]
            num_wins += 1
        end
    end
    STA ./= num_wins
    return STA
end;
# -

function plotSTA(presynspikes)
    STA = calc_STA(presynspikes)
    plot(t_win/ms, STA/mV)
end;

presynspikes = input_spikes.conn.exc[44]
plotSTA(presynspikes);

# ## Test connection

num_shuffles       #=::Int    =#  = 100;

# +
to_ISIs(spiketimes) = [first(spiketimes); diff(spiketimes)]  # copying
to_spiketimes!(ISIs) = cumsum!(ISIs, ISIs)                   # in place

(presynspikes |> to_ISIs |> to_spiketimes!) ≈ presynspikes   # test
# -

shuffle_ISIs(spiketimes) = to_spiketimes!(shuffle!(to_ISIs(spiketimes)));

test_statistic(spiketimes) = spiketimes |> calc_STA |> mean;

# Note difference with 2021: there it was peak-to-peak (max - min). Here it is mean.

function test_connection(presynspikes)
    real_t = test_statistic(presynspikes)
    shuffled_t = Vector{typeof(real_t)}(undef, num_shuffles)
    for i in eachindex(shuffled_t)
        shuffled_t[i] = test_statistic(shuffle_ISIs(presynspikes))
    end
    N_shuffled_larger = count(shuffled_t .> real_t)
    return if N_shuffled_larger == 0
        p_value = 1 / num_shuffles
    else
        p_value = N_shuffled_larger / num_shuffles
    end
end;

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
