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

# # 2022-10-17 • General simulator software design

# In the previous notebook, the firing rate error in the N-to-1 simulations was fixed. We want to know re-run those simulations with actual lognormal Poisson inputs.
#
# When writing the network simulation code, the N-to-1 simulation code was copied and adapted.
# I.e. there is duplication in functionality, and divergence in their APIs.
# It's time for consolidation.
# Advantage: easier to also investigate LIF/EIF neurons, different neuron types, etc.

# ## Imports

# +
#
# -

using MyToolbox

using VoltoMapSim

# ## Poisson spikes

# +

function gen_Poisson_spikes(r, T)
    # The number of spikes N in a time interval [0, T] is ~ Poisson(mean = rT)
    # <--> Inter-spike-intervals ~ Exponential(rate = r).
    # 
    # We simulate the Poisson process by drawing such ISIs, and accumulating them until we
    # reach T. We cannot predict how many spikes we will have at that point. Hence, we
    # allocate an array long enough to very likely fit all of them, and trim off the unused
    # end upon reaching T.
    # 
    max_N = cquantile(Poisson(r*T), 1e-14)  # complementary quantile. [1]
    spikes = Vector{Float64}(undef, max_N)
    ISI_distr = Exponential(inv(r))         # Parametrized by scale = 1 / rate
    N = 0
    t = rand(ISI_distr)
    while t ≤ T
        N += 1
        spikes[N] = t
        t += rand(ISI_distr)
    end
    resize!(spikes, N)
end
# [1] If the provided probability is smaller than ~1e15, we get an error (`Inf`):
#     https://github.com/JuliaStats/Rmath-julia/blob/master/src/qpois.c#L86
#     For an idea of the expected overhead of creating a roomy array: for r = 100 Hz and T =
#     10 minutes, the expected N is 60000, and max_N is 61855.


T = 10minutes
gen_Poisson_spikes(100Hz, T);

# +
function xloghist(x, nbins = 20; kw...)
    fig, ax = plt.subplots()
    a, b = extrema(x)
    bins = 10 .^ range(log10(a), log10(b), nbins)
    ax.hist(x; bins)
    set(ax, xscale = :log; kw...)
end

function yloghist(x, nbins = 20; kw...)
    fig, ax = plt.subplots()
    ax.hist(x, bins = nbins, log = true)
    set(ax; kw...)
end

input_fr = rand(λ_distr, 1000)
xlabel = "Firing rate (Hz)"
yloghist(input_fr; xlabel)
xloghist(input_fr; xlabel)
# -

# ^ that's desired firing rates.
#
# Now to sim the poisson process..

actual_rates = [spikerate(gen_Poisson_spikes(λ, T)) for λ in input_fr]
yloghist(actual_rates; xlabel)
xloghist(actual_rates; xlabel)


