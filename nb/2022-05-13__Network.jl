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

# # 2022-05-13 • A Network

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltoMapSim

# ## Params

p = ExperimentParams(sim=NetworkSimParams());
# dumps(p)

# ## Run sim

state = sim(p.sim);

num_spikes = length.(state.rec.spike_times)

import PyPlot

using VoltoMapSim.Plot

plot(state.rec.voltage_traces[1] / mV);

VI_sigs = add_VI_noise(state, NetworkSimParams(), noisy_VI);

plot(VI_sigs[1] / mV);

# ## Plot sim


