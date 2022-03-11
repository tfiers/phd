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

# # 2022-03-02 • Duration & SNR for big-N–to–1

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

# ## Conntest performance

N_eval_trains = p.evaluation.num_tested_neurons_per_group

α = 0.05;

function evaluate_conntest_performance(vimsig, input_spikes, p)
    
    resetrng!(p.evaluation.rngseed)

    TP_exc = 0
    TP_inh = 0
    TP_unconn = 0

    for input_train in input_spikes.conn.exc[1:N_eval_trains]
        p_value = test_connection(vimsig, input_train, p)
        if p_value < α
            TP_exc += 1
        end
    end

    for input_train in input_spikes.conn.inh[1:N_eval_trains]
        p_value = test_connection(vimsig, input_train, p)
        if p_value > 1 - α
            TP_inh += 1
        end
    end

    for input_train in input_spikes.conn.exc[1:N_eval_trains]
        p_value = test_connection(vimsig, input_train, p)
        if α ≤ p_value ≤ 1 - α
            TP_unconn += 1
        end
    end

    TPR_exc    = TP_exc / N_eval
    TPR_inh    = TP_inh / N_eval
    TPR_unconn = TP_unconn / N_eval
    
    FPR = 1 - TPR_unconn
    
    return TPR_exc, TPR_inh, FPR
end;

evaluate_conntest_performance(vimsig, input_spikes, p)

# ## Performance for given params

function performance_for(p::ExperimentParams)
    _t, _v, vimsig, input_spikes = sim(p.sim);
    return evaluate_conntest_performance(vimsig, input_spikes, p)
end;

const spike_height = cortical_RS.v_peak - cortical_RS.v_rest;

durations = [
    30 * seconds,
    1 * minutes,
    5 * minutes,
    10 * minutes,
    20 * minutes,
];

# +
TPRs_exc = Vector{Float64}()
TPRs_inh = Vector{Float64}()
FPRs     = Vector{Float64}()

for duration in durations
    @show duration / minutes
    TPR_exc, TPR_inh, FPR = performance_for(
        ExperimentParams(
            sim = SimParams(;
                duration,
                imaging = VoltageImagingParams(;
                    spike_SNR = 40,
                    spike_height,
                ),
            ),
        )
    )
    @show TPR_exc, TPR_inh, FPR
    push!(TPRs_exc, TPR_exc)
    push!(TPRs_inh, TPR_inh)
    push!(FPRs, FPR)
    println()
end

# +
xticks = [1:length(durations);]
plott(rates; kwargs...) = plot(xticks, rates; xminorticks = false, kwargs...)

ax = plott(TPRs_exc, label="Excitatory detected")
ax = plott(TPRs_inh, label="Inhibitory detected")
ax = plott(FPRs, label="Unconnected falsely detected")

xlabels = durations / minutes .|> string
ax.set_xticks(xticks)
ax.set_xticklabels(xlabels)
ax.set_xlabel("Recording duration (minutes)")
ax.set_ylabel("Proportion of input connections")
ax.legend();
# -

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
