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

# # 2022-09-29 • Use parametric STA model for connection testing

# ## Imports

# +
#
# -

using MyToolbox

using VoltoMapSim

# Note that we consolidated code from the previous notebook in the codebase (see github, `pkg/VoltoMapSim/src/`)

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

Base.summarysize(out) / GB

# Print info on output of `get_connection_to_test()`
function summarize_conns_to_test(ctt)
    n_post = length(unique(ctt.post))
    println("We test $(nrow(ctt)) putative input connections to $(n_post) neurons.")
    n(typ) = count(ctt.conntype .== typ)
    println("$(n(:exc)) of those connections are excitatory, $(n(:inh)) are inhibitory, "*
            "and the remaining $(n(:unconn)) are non-connections.")
end;

summarize_conns_to_test(conns)

testall(f; α) = test_conns(f, conns, STAs, shuffled_STAs; α);

tc_ptp = testall(test_conn__ptp, α = 0.01);

function summarize_test_results(tc, typpe)
    pm = perfmeasures(tc)
    i = findfirst(pm.conntypes[typpe])
end

pm = perfmeasures(tc_ptp)

perftable(tc_ptp)

# ```
# - 845 exc connections found.
#     - 93% of those are correct.
#     - 52% of all true exc connections were detected.
# ```





length(unique(tc_ptp.post))


