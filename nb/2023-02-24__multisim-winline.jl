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


include("2023-03-14__[setup]_Nto1_sim_AdEx.jl")
cd("/root/phd/nb")
# include("2023-02-24__multisim-winline.jl")

# Num inputs list
Ns_and_δs = [
    (N=5,    δ_nS=5.00),   # => N_inh = 1
    (N=20,   δ_nS=2.30),
    # (N=100,  δ_nS=0.75),
    # (N=400,  δ_nS=0.25),
    # (N=1600, δ_nS=0.08),
    # (N=6500, δ_nS=0.02),
]
# (from `2023-01-19__[input]`).
# Formula for δ: 60 nS / (N * f)
# with f the 'scaling's in the above notebook
# (from 2.4 for N=5 to 0.5 for the biggest two N).

# Ns = [5,20]
# oneliner, for https://github.com/julia-vscode/julia-vscode/issues/3220

seeds = 1:5
seeds = 1:2

duration = 10minutes
duration = 10seconds

conntest_methods = Dict(
    :winpoolreg     => ConnectionTests.WinPoolLinReg(),
    # :STA_corr_2pass => test_conn_STA_corr_2pass,
    # :STA_height     => test_conn_STA_height,
    # :STA_modelfit   => test_conn_STA_modelfit,
)

using MemDiskCache
using ThreadProgress

set_cachedir("2023-02-24__multisim-winpoolreg")

sims = CachedFunction(run_Nto1_AdEx_sim; duration)

function conntest_Nto1_sim(; N, δ_nS, seed, method, N_unconn=100)
    simdata = sims(; N, seed, δ_nS)
    m = conntest_methods[method]
    table = conntest_all(simdata, m; N_unconn)
    return table
end

conntests = CachedFunction(conntest_Nto1_sim)

simkeys = [(; N, δ_nS, seed) for (N, δ_nS) in Ns_and_δs, seed in seeds]

println("Starting threaded foreach")
threaded_foreach_with_pbar(simkeys) do kw
    for method in keys(conntest_methods)
        conntests(; kw..., method)
    end
    rm_from_memcache!(sims; kw...)
end
