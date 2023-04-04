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

cd(joinpath(homedir(), "phd", "pkg" , "SpikeWorks"))
run(`git switch metdeklak`)
# ↪ Doing here and not in include, as multiprocs on same git repo crashes

cd(joinpath(homedir(), "phd"))
Pkg.activate(".")
# To paste in terminal, if you wanna run this whole file at once:
# > include("nb/2023-02-24__multisim-winline.jl")

using WithFeedback
@withfb using SpikeWorks.Units

# Num inputs list
Ns_and_δs = [
    (N=5,    δ_nS=5.00),   # => N_inh = 1
    (N=20,   δ_nS=2.30),
    (N=100,  δ_nS=0.75),
    (N=400,  δ_nS=0.25),
    (N=1600, δ_nS=0.08),
    (N=6500, δ_nS=0.02),
]
# (from `2023-01-19__[input]`).
# Formula for δ: 60 nS / (N * f)
# with f the 'scaling's in the above notebook
# (from 2.4 for N=5 to 0.5 for the biggest two N).

seeds = 1:5
# seeds = 1:3

duration = 10minutes
# duration = 30seconds

simkeys = [
    (; N, δ_nS, seed, duration)
    for (N, δ_nS) in Ns_and_δs,
        seed in seeds
]

using DistributedLoopMonitor

@start_workers(4)
@everywhere include("2023-03-14__[setup]_Nto1_sim_AdEx.jl")
    # Path is always relative  to current file

@everywhere conntest_method_names = [
    :fit_upstroke,
    :STA_height,
    :STA_corr_2pass,
]

@everywhere N_unconn = 100

# for simkw in simkeys
distributed_foreach(simkeys) do simkw
    for method in conntest_method_names
        conntest_tables(; simkw..., method, N_unconn)
    end
    rm_from_memcache!(sims; simkw...)
end

using ConnTestEval

# sweeps = sweep_threshold.(conntest_tables)
