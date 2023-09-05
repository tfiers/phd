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

# # 2023-09-05 · Inhibitory impulse response (PSP)

# We've had excitatory (https://tfiers.github.io/phd/nb/2023-07-26__AdEx_Nto1_we_I_syn.html#impulse-response), \
# but inh is interesting too: same syn strength, same PSP? Or no.

include("lib/Nto1.jl")

#
