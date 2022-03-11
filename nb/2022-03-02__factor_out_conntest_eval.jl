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

    for input_train in input_spikes.unconn[1:N_eval_trains]
        p_value = test_connection(vimsig, input_train, p)
        if α/2 ≤ p_value ≤ 1 - α/2
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
