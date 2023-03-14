# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Julia 1.9.0-beta3
#     language: julia
#     name: julia-1.9
# ---

# # 2023-02-24 • Multi-sim Window pool regression



# Num inputs list
Ns = [
    5,   # => N_inh = 1
    20,
    100,
    400,
    1600,
    6500,
]
# (from `2023-01-19__[input]` (which also included a 'scaling' for each N))

seeds = 1:5

duration = 10minutes

using ConnectionTests

conntest_methods = Dict(
    :winpoolreg     => WinPoolLinReg(),
    # :STA_corr_2pass => test_conn_STA_corr_2pass,
    # :STA_height     => test_conn_STA_height,
    # :STA_modelfit   => test_conn_STA_modelfit,
)

using MemDiskCache
using ThreadProgress

set_cachedir("2023-02-24__multisim-winpoolreg")

sims = CachedFunction(run_Nto1_AdEx_sim; duration)

function conntest_Nto1_sim(; N, seed, method)
    simdata = sims(; N, seed)
    # [add unconns]
    v = voltsig(simdata)
    m = conntest_methods[method]
    for spiketrain in spikertrains(simdata)
        t = test_conn(m, spiketrain, v)
        row = (true_type, t)
    end
    return table
end

conntests = CachedFunction(conntest_Nto1_sim)

simkeys = [(; N, seed) for N in Ns, seed in seeds]
threaded_foreach(simkeys) do kw
    for method in keys(conntest_methods)
        conntests(; kw.N, kw.seed, method)
    end
    delete_from_memory!(sims; kw...)
end
