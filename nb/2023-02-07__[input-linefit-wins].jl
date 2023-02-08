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

# # 2023-02-07 • [input] to 'AdEx Nto1'

# Distilation of `2023-01-19 • Fit-a-line`.

# ## Windows

winsize = 100;  # first 10 ms

# +
function windows(v, times, Δt, winsize)
    # Assuming that times occur in [0, T)
    win_starts = floor.(Int, times / Δt) .+ 1
    wins = Vector{Vector{eltype(v)}}()
    for a in win_starts
        b = a + winsize - 1
        if b ≤ lastindex(v)
            push!(wins, v[a:b])
        end
    end
    return wins
end

windows(i_sim, spiketimes) = windows(
    vrec(sims[i_sim]),
    spiketimes,
    Δt,
    winsize,
)

windows(i_sim, i_input::Int) = windows(i_sim, spiketimes(inps[i_sim].inputs[i_input]));


# +
# check for type inferrability
# st = spiketimes(inp.inputs[1])
# @code_warntype windows(vrec(sim), st, Δt, winsize)
# ok ✔

# +
# @time wins = windows(1, 1);
# println()
# print(Base.summary(wins))
# -


# Now to make the data matrix

# ## Data matrix

# We'll fit slope and intercept. So each datapoint, each row of X, is `[1, t]`

# +
function build_Xy(windows, timepoints = 1:100)
    T = eltype(eltype(windows))
    N = length(windows) * length(timepoints)
    X = Matrix{T}(undef, N, 2)
    y = Vector{T}(undef, N)
    i = 1
    for win in windows
        for (tᵢ, yᵢ) in zip(timepoints, win[timepoints])
            X[i,:] .= [1, tᵢ]
            y[i] = yᵢ
            i += 1
        end
    end
    @assert i == N + 1
    return (X, y)
end;


# @time X, y = build_Xy(wins);

# +
# check for type inferrability
# @code_warntype build_Xy(wins, 1:100)
# ok ✔

# +
# size(X)

# +
# size(y)
# -

# ## Plot some windows

# +
# ts = @view X[:,2]
# sel = 1:10000

# plot(ts[sel]*Δt/ms, y[sel]/mV, ".", alpha=0.1);

# +
# Ny = length(y)
# -

# 3M datapoints (one connection, 10 minutes recording)

# +
# sel = 1:100_000

# plot(
#     ts[sel]*Δt/ms,
#     y[sel]/mV,
#     ".";
#     alpha = 0.01,
#     ylim = [-50, -40],  # mV
#     clip_on = true,
# );
# -

# (Not very informative)

# ## Use as conntest

# +
# inh_neurons = Nₑ+1:N

# +
# niᵢ = Nₑ + argmax(actual_spike_rates[inh_neurons])

# +
# actual_spike_rates[niᵢ] / Hz
# -

"""
Fit straight line to first 100 ms of
windows cut out of output neuron's voltage signal,
aligned to given times `z`
(or spiketimes of input neuron w/ index `z`).
(for simulation index iₛ)
"""
fitwins(z, iₛ=i) = begin
    wins = windows(iₛ, z)
    X, y = build_Xy(wins)
    β̂ = vec(X \ y)
    ŷ = X * β̂
    ε̂ = y .- ŷ
    return (;
        X, y, β̂,
        intercept   = β̂[1] / mV,       # in mV
        slope       = β̂[2] / mV / Δt,  # in mV/second
        predictions = ŷ,
        residuals   = ε̂,
    )
end;

# +
# check for type inferrability
# @code_warntype fitwins(niᵢ)
# ok ✔

# +
# @time fitwins(niᵢ).slope

# +
spiketimes(i::Int) = spiketimes(inp.inputs[i])

# stₑ = spiketimes(niₑ)

# @time fitwins(shuffle_ISIs(stₑ)).slope
# -

using Distributions

# ### Summary

function htest(fit)
    (; X, y, β̂) = fit
    n = length(y)
    p = 2  # Num params
    dof = n - p
    ε̂ = fit.residuals
    s² = ε̂' * ε̂ / dof
    Q = inv(X' * X)
    σ̂β₂ = √(s² * Q[2,2])
    t = β̂[2] / σ̂β₂
    𝒩 = Normal(0, 1)
    pval = cdf(𝒩, -abs(t)) + ccdf(𝒩, abs(t))
    noise_mV = √s² / mV
    return (; t, pval, noise_mV)
end;

# +
# htest(fitt)

# +
# @time htest(fitt);
# -

# That's fast :)

function conntest(z; α = 0.05)
    fit = fitwins(z)
    test = htest(fit)
    if test.pval < α
        predtype = (fit.slope > 0 ? :exc : :inh)
    else
        predtype = :unconn
    end
    return (;
        fit.slope,
        test.pval,
        predtype,
    )
end;

# +
# conntest(niₑ)

# +
# conntest(niᵢ)
# -

# Let's try on shuffled spiketrains

# +
# shuffled(ni) = shuffle_ISIs(spiketimes(ni));

# +
# conntest(shuffled(niₑ))
# -

# ## Eval

# +
# DataFrame(conntest(shuffled(niₑ)) for _ in 1:10)
# -

# Ok this is similar as in prev instantiation of this notebook / prev sim.
#
# (The three unconns above were thus lucky).

# ### Proper eval

# I didn't sim a 100 unconnected spikers, as before.\
# So we can't use that for an FPR estimate.\
# But we can shuffle some real spiketrains to get sth similar.\
# Let's draw from all, so there's a mix of spikerates.

# +
# ids = sample(1:N, 100, replace=true)
# unconnected_trains = shuffle_ISIs.(spiketimes.(ids));
# -

# Our `perftable` expects a dataframe with :predtype and :conntype columns

# +
# inh_neurons

# +
# real_spiketrains = spiketimes.(1:N);

# +
# all_spiketrains = [real_spiketrains; unconnected_trains];

# +
conntype(i) = 
    if i < Nₑ
        conntype = :exc
    elseif i ≤ N
        conntype = :inh
    else
        conntype = :unconn
    end

makerow(i; α=0.001) = begin
    spikes = all_spiketrains[i]
    test = conntest(spikes; α)
    (; conntype = conntype(i), test...)
end;

# +
# @time makerow(1)

# +
# @time makerow(6600)

# +
conntest_all() = @showprogress map(makerow, eachindex(all_spiketrains));

# rows = cached(conntest_all, [], key="2023-01-19__Fit-a-line");

# +
# df = DataFrame(rows)
# df |> disp(20)

# +
# perftable(df)
# -

# (Code should be written / dug up to sweep threshold i.e. get AUC scores etc, but):
#
# At this arbitrary 'α' = 0.001:\
# FPR: 34%\
# TPRₑ: 24%\
# TPRᵢ: 37%
