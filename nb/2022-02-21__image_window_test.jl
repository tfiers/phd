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

# # 2022-02-21 • Image, window, test

# ## Setup

# +
# using Pkg; Pkg.resolve()
# -

using Revise

using MyToolbox

using VoltageToMap

# ## Params & sim


# Short warm-up run. Get compilation out of the way.

p = SimParams(
    poisson_input = small_N__as_in_Python_2021,
    sim_duration  = 1*minutes
)
@time sim(p);

p = SimParams(
    poisson_input = realistic_input,
    sim_duration  = 10*seconds,
    Δg_multiplier = 0.1,
)
dump(p)

t, v, input_spikes = @time sim(p);

# ## Plot

import PyPlot

using Sciplotlib

""" tzoom = [200ms, 600ms] e.g. """
function plotsig(t, sig, tzoom = nothing, clip_on=false)
    isnothing(tzoom) && (tzoom = t[[1, end]])
    izoom = first(tzoom) .≤ t .≤ last(tzoom)
    plot(t[izoom], sig[izoom]; clip_on)
end;

plotsig(t, v / mV);

plotsig(t, v / mV, [200ms,400ms]);


