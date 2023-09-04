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
duration = 10 * minutes
N = 6500

@time sim = Nto1AdEx.sim(N, duration);
# -





include("lib\\plot.jl")
