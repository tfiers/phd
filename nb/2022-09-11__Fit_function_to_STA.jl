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

# # 2022-09-11 • Fit function to STA

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Params

p = get_params(
    duration = 10minutes,
    p_conn = 0.04,
    g_EE = 1,
    g_EI = 1,
    g_IE = 4,
    g_II = 4,
    ext_current = Normal(-0.5 * pA/√seconds, 5 * pA/√seconds),
    E_inh = -80 * mV,
    record_v = [1:40; 801:810],
);

# ## Run sim

s = cached(sim, [p.sim]);

s = augment(s, p);

# ## ...

# From previous notebook, median input detection rates, for both our old connection test technique (peak-to-peak and area-over-start for exc/inh decision) and the new one, where we cheated with info of the average E→E STA:
#
# ```
#             ptp-area  corr-with-avgSTA 
# ──────────────────────────────────────
#  exc → exc      0.57              0.79
#  exc → inh      0.57              0.82
#  inh → exc      0.88              1.00
#  inh → inh      0.81              0.96
# ```

# If we don't cheat, but still use the "template"- or "canonical STA shape"-matching idea, can we still beat the `ptp-area` detection rates?

# From the "Model PSP" section [here](https://tfiers.github.io/phd/nb/2022-09-05__Why-not-detected.html#model-psp), we have a functional form for a PSP.
#
# ..But not for an STA, which shows an additional dimple.  
#
# Let's not research additional theoretical justification for the STA shape (something to do with spike shape and postsynaptic firing probabilities...), but rather make a guess at an empirical function.
#
# For now, we just try to emulate the STA dimple by subtracting a gaussian dip from our exponential model of the PSP.

# @time calc_avg_STA(s, p, postsyn_neurons = 1:40, inputs = s.exc_inputs);
@time calc_avg_STA(s, p, 1:40, s.exc_inputs);

@time calc_avg_STA_v2(s, p, 1:40, s.exc_inputs);

STAs = (calc_STA(m => n, s, p) for n in 1:40 for m in s.exc_inputs[n]);
@time mean(STAs);

@code_warntype calc_avg_STA(s, p, 1:40, s.exc_inputs);



@code_warntype calc_STA(1 => 1, s, p)

@code_warntype calc_STA(s.signals[1].v, s.spike_times[2], p)

# @code_warntype VoltoMapSim.calc_avg_STA_v2(s, p, postsyn_neurons = 1:40, inputs = s.exc_inputs);
@code_warntype VoltoMapSim.calc_avg_STA_v2(s, p, 1:40, s.exc_inputs);


