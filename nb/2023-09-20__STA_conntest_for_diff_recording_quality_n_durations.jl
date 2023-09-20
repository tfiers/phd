# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Julia 1.9.3
#     language: julia
#     name: julia-1.9
# ---

# # 2023-09-20 · STA conntest for diff recording quality n durations 

include("lib/Nto1.jl")

N = 6500
duration = 10minutes
@time sim = Nto1AdEx.sim(N, duration);  # ceil_spikes is true by default

# +
(; Vₛ, Eₗ) = Nto1AdEx

function VI_sig(sim; spike_SNR = 10, spike_height = (Vₛ - Eₗ), seed=1)
    Random.seed!(seed)
    σ = spike_height / spike_SNR
    sig = copy(sim.V)
    sig .+= (σ .* randn(length(sig)))
    sig
end;

sig = VI_sig(sim);
# -

include("lib/plot.jl")

plotsig(sig, [0,1000], ms, yunit=:mV);

# Very good.

VI_sig(sim, spike_SNR=Inf) == sim.V

# Excellent.

for spike_SNR in [Inf, 10, 4, 2, 1]
    perf = test_conns(sim)
end








