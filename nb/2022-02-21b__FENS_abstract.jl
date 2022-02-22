# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.6
#   kernelspec:
#     display_name: Julia 1.7.1
#     language: julia
#     name: julia-1.7
# ---

# # 2022-02-21 • FENS 2022 Abstract

# As usually, the reusable code of the previous notebook 
# has been added in [`pkg/VoltageToMap/src/`](https://github.com/tfiers/voltage-to-wiring-sim/tree/main/pkg/VoltageToMap/src),
# and is imported below.

# ## Setup

# +
# 
# -

using Revise  # Reloads src code without having to restart kernel

using MyToolbox

using VoltageToMap

# ## Params & sim


# Short warm-up run. Get compilation out of the way.

p0 = ExperimentParams(sim=SimParams(inputs=previous_N_30_inputs, duration=1 * minutes));

@time sim(p0.sim);

# + tags=["output_scroll"]
p = ExperimentParams(
    sim = SimParams(
        inputs = realistic_N_6600_inputs,
        duration = 10 * minutes,
        synapses = SynapseParams(Δg_multiplier = 0.066),
    )
)
dumpc(p)
# -

t, v, input_spikes = @time sim(p.sim);

num_spikes = length.(input_spikes)

# ## Plot

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

resetrng!(p.sim.seed)
noise = randn(length(v)) * p.sim.imaging.σ_noise
vimsig = v + noise;

ax = plotsig(t, vimsig / mV, [200ms,1200ms], xlabel="Time (s)", hylabel="mV", alpha=0.7);
plotsig(t, v / mV, [200ms,1200ms], xlabel="Time (s)", hylabel="mV"; ax);

# ## Window

# +
const window_length = p.conntest.STA_window_length
const Δt = p.sim.Δt
const win_size = round(Int, window_length / Δt)
const t_win = linspace(zero(window_length), window_length, win_size)  # for plottin

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

example_presynspikes = rand(input_spikes.conn.exc)
plotSTA(example_presynspikes);

# ## Test connection

# +
to_ISIs(spiketimes) = [first(spiketimes); diff(spiketimes)]  # copying
to_spiketimes!(ISIs) = cumsum!(ISIs, ISIs)                   # in place

(example_presynspikes |> to_ISIs |> to_spiketimes!) ≈ example_presynspikes   # test
# -

shuffle_ISIs(spiketimes) = to_spiketimes!(shuffle!(to_ISIs(spiketimes)));

test_statistic(spiketimes) = spiketimes |> calc_STA |> mean;

# Note difference with 2021: there it was peak-to-peak (max - min). Here it is mean.

# +
const num_shuffles = p.conntest.num_shuffles

function test_connection(presynspikes)
    real_t = test_statistic(presynspikes)
    shuffled_t = Vector{typeof(real_t)}(undef, num_shuffles)
    resetrng!(p.conntest.seed)
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
# -

# ## Results

p_exc

# +
num_trains = p.evaluation.num_tested_neurons_per_group
num_trains = 300

resetrng!(p.evaluation.seed)
tested_spike_trains_exc = rand(input_spikes.conn.exc, num_trains)
tested_spike_trains_inh = rand(input_spikes.conn.inh, num_trains)
tested_spike_trains_unconn = rand(input_spikes.unconn, min(num_trains, 100))

p_exc    = Float64[]
p_inh    = Float64[]
p_unconn = Float64[]

for (groupname, spiketrains, pvals) in (
        ("excitatory",    tested_spike_trains_exc,    p_exc),
        ("inhibitory",    tested_spike_trains_inh,    p_inh),
        ("unconnected",   tested_spike_trains_unconn, p_unconn),
    )
    @showprogress 200ms groupname for spiketrain in spiketrains
        push!(pvals, test_connection(spiketrain))
    end
end
# -

best_exc = tested_spike_trains_exc[p_exc .== minimum(p_exc)]
best_inh = tested_spike_trains_inh[p_inh .== maximum(p_inh)]
length(best_exc), length(best_inh)

st_exc_i, st_exc = rand(pairs(best_exc))
st_inh_i, st_inh = rand(pairs(best_inh))
plotSTA(st_exc)
plotSTA(st_inh)
st_exc_i, st_inh_i

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
Sciplotlib.set(ax, xlim=(0.33, 3.3), ylim=(0, 1), xaxis=:off)
hylabel(ax, L"p(\, \mathrm{shuffled\ \overline{STA}} \ > \ \mathrm{actual\ \overline{STA}}\, )"; dy=10);
