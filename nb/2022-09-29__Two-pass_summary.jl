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

# # 2022-09-29 • Summary of two-pass conntest

# This notebook is a summary of the previous one,
# where all its new code has consolidated in the codebase (see github, `pkg/VoltoMapSim/src/`).

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

Base.summarysize(out) / GB

# +
# Print info on output of `get_connection_to_test()`
function summarize_conns_to_test(ctt)
    n_post = length(unique(ctt.post))
    println("We test ", nrow(ctt), " putative input connections to ", n_post, " neurons.")
    n(typ) = count(ctt.conntype .== typ)
    println(n(:exc), " of those connections are excitatory, ", n(:inh), " are inhibitory, ",
            "and the remaining ", n(:unconn), " are non-connections.")
end

summarize_conns_to_test(conns)
# -

# ## Test

# First peak-to-peak, strict alpha of 0.01 (`tc_ptp`).
#
# Then correlate with found average exc STA, alpha 0.05 (`tc_corr`).
#
# ---

testall(f; α) = test_conns(f, conns, STAs, shuffled_STAs; α);

tc_ptp = testall(test_conn__ptp, α = 0.01);

# +
function summarize_test_results(tc, typ)
    pm = perfmeasures(tc)
    println(pm.num_pred[typ], " $typ connections found. ", fmt_pct(pm.precision[typ]), " of those are correct.")
    println("The correct $typ detections make up ", fmt_pct(pm.sensitivity[typ]), " of all true $typ connections.")
end

summarize_test_results(tc_ptp, :exc)
# -

avg_ptp_exc_STA = mean(STAs[conn.pre => conn.post] for conn in eachrow(tc_ptp) if conn.predtype == :exc);

tc_corr = testall(test_conn__corr $ (; template = avg_ptp_exc_STA), α = 0.05);

# +
function summarize_test_results(tc)
    summarize_test_results(tc, :exc)
    println()
    summarize_test_results(tc, :inh)
    println()
    summarize_test_results(tc, :unconn)
end

summarize_test_results(tc_corr)
# -

perftable(tc_corr)
