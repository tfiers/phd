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

# # 2023-08-31__STA_conntest

# So, hi.
# copying from prev nb:
#
# So, for all 10 Ns;\
# For 10 diff seeds;
# for both exc, inh, and unconn;\
# we conntest (maximum) 100 input spike trains.\
# (Each test is comprised of calculating 101 STAs: one real and the rest with shuffled ISIs).

include("lib/Nto1.jl")

# +
duration = 10minutes
N = 6500

@time sim = Nto1AdEx.sim(N, duration);
# -

# (So even with native code caching in Julia 1.9, we still have 30% of time compilation here).

# We decided we'd pick the 100 highest firing (exc and inh).\
# And then generate some unconnecteds too..\
# What's their firing rate? Maybe sample from the real ones :) hehe, sure.

exc = highest_firing(excitatory_inputs(sim))[1:100]
inh = highest_firing(inhibitory_inputs(sim))[1:100]
both = [exc..., inh...]
fr = spikerate.(both)
showsome(fr / Hz)







include("lib\\plot.jl")
