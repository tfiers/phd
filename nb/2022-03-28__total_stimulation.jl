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

# # 2022-03-28 • The invariant measure: total stimulation

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
        duration = 1 * minutes,
        synapses = SynapseParams(
            Δg_multiplier = 0.066,
        ),
        imaging = VoltageImagingParams(
            spike_height = cortical_RS.v_peak - cortical_RS.v_rest,
            spike_SNR = Inf,
        )
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

# (Perfect overlap of Vm and VI sig: ∞ SNR)

# ## Total stimulation

# +
# 

# +
init_state = # init_sim(p).state.fixed_at_init

@. total_stim = # init_state.Δg * num_spikes
# -

# ## p-values

for train in …:
    p_value = test_connection(…)

# ## Plot

plot(total_stim, p_value)

# ..but separated by exc, inh, unconn.





example_presynspikes = input_spikes.conn.exc[44]
plotSTA(vimsig, example_presynspikes, p);

p_value = test_connection(vimsig, example_presynspikes, p)

N_eval_trains = p.evaluation.num_tested_neurons_per_group
