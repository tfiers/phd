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
        duration = 10 * minutes,
        synapses = SynapseParams(
            Δg_multiplier = 0.066,
        ),
        imaging = get_VI_params_for(
            cortical_RS,
            spike_SNR = Inf
        ),
    )
);
dumps(p)

t, v, vimsig, input_spikes, state = @time sim(p.sim);

num_spikes = length.(input_spikes)

# ## Plot

import PyPlot

using VoltageToMap.Plot

tzoom = [200, 1200]ms
ax = plotsig(t, vimsig / mV, tzoom; xlabel="Time (s)", hylabel="mV", alpha=0.7);
plotsig(t, v / mV, tzoom; ax);

# (Perfect overlap of Vm and VI sig: ∞ SNR)

# ## Total stimulation

total_stim = num_spikes.conn .* state.fixed_at_init.Δg
round.(total_stim / nS)

style = copy(sciplotlib_style)
style["xaxis.labellocation"] = "right"
set_mpl_style!(style);

fig, ax = plt.subplots()
ax.hist(total_stim.exc / nS, color="C2", label="Excitatory")
ax.hist(total_stim.inh / nS, color="C1", label="Inhibitory")
ax.set_xlim(left=0)
set(ax, xlabel="Total stimulation (nS)", ylabel="# Input connections")
ax.legend();

ax = plot(total_stim.exc / nS, num_spikes.conn.exc, "C2.", clip_on=false)
ax = plot(total_stim.inh / nS, num_spikes.conn.inh, "C1.", ax, clip_on=false)
ax.set_xlim(left=0)
ax.set_ylim(bottom=0)
set(ax, hylabel="# spikes", xlabel="Total stimulation (nS)");

# ## p-values

# Testing all input connections takes too long.
# So we want to select only the most stimulating ones.

N_selected_per_class = 100;

# +
get_indices_of_N_highest(arr, N) = partialsortperm(arr, 1:N, rev = true)  # = `maxk` in matlab

strongest_exc = get_indices_of_N_highest(total_stim.exc, N_selected_per_class)
strongest_inh = get_indices_of_N_highest(total_stim.inh, N_selected_per_class);

chosen_exc = strongest_exc
chosen_inh = strongest_inh;
# -

# No actually let's take random sample.

chosen_exc = 1:N_selected_per_class
chosen_inh = 1:N_selected_per_class;

total_stim__sel = CVec(
    exc = total_stim.exc[chosen_exc],
    inh = total_stim.inh[chosen_inh]
)
input_spike_trains__sel = (
    exc = input_spikes.conn.exc[chosen_exc],
    inh = input_spikes.conn.inh[chosen_inh],
);  # no CVec (as components are arrays, not scalars).

# +
p_values = similar(total_stim__sel, Float64)

@showprogress 400ms for (i, presynspikes) in enumerate(input_spike_trains__sel.exc)
    p_values.exc[i] = test_connection(vimsig, presynspikes, p)
end
@showprogress 400ms for (i, presynspikes) in enumerate(input_spike_trains__sel.inh)
    p_values.inh[i] = 1 - test_connection(vimsig, presynspikes, p)
end
# -

# ## Plot

ax = plot(total_stim__sel.exc / nS, p_values.exc, "C2.", label="Excitatory", clip_on=false)
ax = plot(total_stim__sel.inh / nS, p_values.inh, "C1.", ax, label="Inhibitory", clip_on=false)
α = 0.05
ax.axhline(α, color="black", zorder=3, lw=1, linestyle="dashed", label=f"α = {α:.3G}")
set(ax, xlabel="Total stimulation (nS)", hylabel="p-value of connection test", ylim=[0,1])
ax.legend(loc="upper left", bbox_to_anchor=(0.7, 1));

# ^ is for a random selection of inputs.
#
# The below is for the N strongest inputs:

# +
# (rerun and lose)
# -


