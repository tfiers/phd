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

# # 2023-01-19 • Fit a line

# We're working off `2022-10-24 • N-to-1 with lognormal inputs`.
#
# But trying a new detection method.
#
# (Linear regression of voltage against time-post-spike)
#
# Note that, unlike in earlier sims, there is no transmission delay added in the latest sim.

# + [markdown] tags=[]
# ## Setup
# -

# I'll put the work from previous notebook in a script (not package, this time)

# (Thanks to 'jupytext' extension, that script'll also be a notebook)

# + tags=[]
include("2023-01-19__[input].jl");
# -

# (I disabled STA calculating/caching/loading in there: we're gon work on individual windows).

# ## Start

# We'll tackle the most difficult case.

i = 6

N = Ns[i]

sim = sims[i]

spikerate(sim) / Hz  # ..of the single output neuron

inp = inps[i];

# ---

# So we could fit an STA. then there's one `y` per `x`; a 100 `x`s (for 10 ms post 'arrival').
#
# Or we could do individual windows. Let's do that.
# (How many datapoints then?
#
# 50 Hz input for 10minutes:

_numspikes = 50Hz*10minutes

# So 30_000 windows. And 30_000 `y`'s per `x`. (per `t`, actually)

# Let's find highest spiking exc neuron

actual_spike_rates = spikerate_.(inp.inputs);

for f in [minimum, median, mean, maximum]
    println(lpad(f, 8), ": ", f(actual_spike_rates), " Hz")
end

Nₑ = inp.Nₑ

_, ni = findmax(actual_spike_rates)

# +
calcSTA(ni) = calcSTA(sim, spiketimes(inp.inputs[ni]))

plot(calcSTA(ni) / mV);
# -

# But we're not fitting STAs, we're fitting indiv windows.
# So.

# (Wow, this one (3743, on WSL) is weird).

# ## Windows

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

windows(spiketimes) = windows(
    vrec(sim),
    spiketimes,
    Δt,
    winsize,
)

windows(i::Int) = windows(spiketimes(inp.inputs[i]));


# +
# check for type inferrability
# st = spiketimes(inp.inputs[1])
# @code_warntype windows(vrec(sim), st, Δt, winsize)
# ok ✔
# -

@time wins = windows(ni);
println()
print(Base.summary(wins))


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
end


@time X, y = build_Xy(wins);

# +
# check for type inferrability
# @code_warntype build_Xy(wins, 1:100)
# ok ✔
# -

size(X)

size(y)

# Some example data:

# +
_r = 95:105

[X[_r, :] y[_r] / mV]
# -

# So for our model `y = ax + b`  (w/ `β = [b, a]`)
#
# `x` is in units of 'timestep'\
# So `a` will be too: mV/timestep

# ## Solve

# Linear regression *assuming Gaussian noise* → MSE, 'OLS', normal equations

# `?\` → "`\(X,y)` for rectangular `X`:\
# minimum-norm least squares solution computed by \
# a pivoted QR factorization of `X` \
# and a rank estimate of `X` based on the R factor"
#

@time β̂ = X \ y

# (First run time i.e. including compilation: 4 seconds)

intercept = β̂[1] / mV

# Ok check

# For the slope,

slope = β̂[2] / mV

# That's per timestep.

# Per second:

slope / Δt

# ## Plot some windows

# +
ts = @view X[:,2]
sel = 1:10000

plot(ts[sel]*Δt/ms, y[sel]/mV, ".", alpha=0.1);
# -

# It's the spikes we see there.\
# (and the unrealistically slow quadratic ramp-ups of Izhikevich)
#
# so let's zoom in

Ny = length(y)

# 3M datapoints (one connection, 10 minutes recording)

# +
sel = 1:100_000

plot(
    ts[sel]*Δt/ms,
    y[sel]/mV,
    ".";
    alpha = 0.01,
    ylim = [-50, -40],  # mV
    clip_on = true,
);
# -

# (Not very informative)

# ## Use as conntest

# (We could look at uncertainty / goodness of fit but not now)

# First, let's see what fitted slope is for an inh input; and a shuffled one.

inh_neurons = Nₑ+1:N

niᵢ = Nₑ + argmax(actual_spike_rates[inh_neurons])

actual_spike_rates[niᵢ] / Hz

"""
Fit straight line to first 100 ms of
windows cut out of output neuron's voltage signal,
aligned to given times `z`
(or spiketimes of input neuron w/ index `z`).
"""
fitwins(z) = begin
    wins = windows(z)
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
# -

@time fitwins(niᵢ).slope

# (First run time: 2.7 seconds)

niₑ = ni

@time fitwins(niₑ).slope

# +
spiketimes(i::Int) = spiketimes(inp.inputs[i])

stₑ = spiketimes(niₑ)

@time fitwins(shuffle_ISIs(stₑ)).slope
# -

# Okido

# Now, to use as conntest.
#
# Null hypothesis is that slope = 0

# Refresher at
# https://gregorygundersen.com/blog/2021/09/09/ols-hypothesis-testing/

# ### Hypothesis testing

# If the slope actually were 0\
# (i.e. $b_p = b_1 = 0$ in the post),
#
# (and if noise were gaussian, which it's not given the assymetric spiking)
#
# then we expect the slope ("$β̂_1$"), to be distributed as:

# $$
# \hat{β}_1 \sim \mathcal{N}(0, σ² Q_{[2,2]})
# $$
# where $Q$ is the inverse of the Gram matrix $X^T X$:
#
# $$
# Q = (X'X)^{-1}
# $$
#
# ($Q$ 'is related to' the covariance matrix, and is called the cofactor matrix.\
# https://en.wikipedia.org/wiki/Ordinary_least_squares#Estimation)
#
# ..and with $σ$ the (unkown) standard-deviation of our
# supposedly-Gaussian-distributed noise $ε$ in our model
#
# $$
# y_i = β_0 + β_1 x_i + ε_i,
# $$
# i.e.
#
# $$
# ε \sim \mathcal{N}(0, σ²).
# $$
#
# ('$Q_{[2,2]}$' is the second diagonal element of $Q$.
# The indices are off-by-one as the intercept is conventionally $β_0$ instead of $_1$).

# ### Estimate noise on model

fitt = fitwins(niₑ);

n = length(fitt.y)
p = 2  # Num params
dof = n - p

ε̂ = fitt.residuals;

# OLS estimate of variance σ² of Gaussian noise ε:

s² = ε̂' * ε̂ / dof

# MLE estimate:

σ̂² = ε̂' * ε̂ / n

# (ofc virtually same cause ridic amount of datapoints)

# So estimate for stddev of noise on our line, in mV:

√s² / mV

# Seems about right.

# ### Gram matrix

X = fitt.X
G = X' * X  # not calling it N, that's used already

Q = inv(G)

# So, estimated stddev of our slope distribution.

σ̂β₂ = √(s² * Q[2,2])

σ̂β₂ / mV

# Aka standard error or 'se($\hat{β}_2$)'

# ### t-statistic

# Slope in mV:

fitt.slope

# In original units of the (X,y) fit, i.e. volt/timestep:

β̂₂ = fitt.β̂[2]

t = β̂₂ / σ̂β₂

# That value follows the Student's t-distribution with `n-p` degrees of freedom,\
# which, at our

dof

# is same as Normally distributed.

using Distributions

𝒩 = Normal()

# Null-hypothesis is that slope == 0.\
# So alternative is that it can be both larger and smaller.

# Critical values:

α = 0.05

quantile(𝒩, α/2)

cquantile(𝒩, α/2)

# So yes our slope is significant.
#
# By how much, i.e. what's p-value

# I.e. probability of `t` being at least this large, under H₀.

pval = cdf(𝒩, -t) + ccdf(𝒩, t)

# i.e. p < 0.05
#
# This happens by chance once in

1/pval

# 1_8400_000_000 universes.

# Now to package this up in a function

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

htest(fitt)

@time htest(fitt);

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

conntest(niₑ)

conntest(niᵢ)

# Let's try on shuffled spiketrains

shuffled(ni) = shuffle_ISIs(spiketimes(ni));

conntest(shuffled(niₑ))

conntest(shuffled(niₑ))

conntest(shuffled(niᵢ))

# That's not great.
#
# (In previous iteration of this notebook, with a different sim, all three of these were `:unconn`)

# ## Eval

DataFrame(conntest(shuffled(niₑ)) for _ in 1:10)

# Ok this is similar as in prev instantiation of this notebook / prev sim.
#
# (The three unconns above were thus lucky).

# ### Proper eval

# I didn't sim a 100 unconnected spikers, as before.\
# So we can't use that for an FPR estimate.\
# But we can shuffle some real spiketrains to get sth similar.\
# Let's draw from all, so there's a mix of spikerates.

ids = sample(1:N, 100, replace=true)
unconnected_trains = shuffle_ISIs.(spiketimes.(ids));

# Our `perftable` expects a dataframe with :predtype and :conntype columns

inh_neurons

real_spiketrains = spiketimes.(1:N);

all_spiketrains = [real_spiketrains; unconnected_trains];

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
# -

@time makerow(1)

@time makerow(6600)

# +
conntest_all() = @showprogress map(makerow, eachindex(all_spiketrains))

rows = cached(conntest_all, [], key="2023-01-19__Fit-a-line");
# -

df = DataFrame(rows)
df |> disp(20)

perftable(df)

# (Code should be written / dug up to sweep threshold i.e. get AUC scores etc, but):
#
# At this arbitrary 'α' = 0.001:\
# FPR: 34%\
# TPRₑ: 24%\
# TPRᵢ: 37%
