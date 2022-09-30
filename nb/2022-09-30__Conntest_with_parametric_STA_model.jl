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
#     display_name: Julia 1.8.1 mysys
#     language: julia
#     name: julia-1.8-mysys
# ---

# # 2022-09-30 • Use parametric STA model for connection testing

# ## Imports

# +
#
# -

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

# ## Load STA's

# (They're precalculated).

out = cached_STAs(p);

(conns, STAs, shuffled_STAs) = out;


