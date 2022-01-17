# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.10.0
#   kernelspec:
#     display_name: Julia 1.7.0
#     language: julia
#     name: julia-1.7
# ---

# # 2022-01-08 • 1000-to-1

include("nb_init.jl");

save = savefig $ (; subdir="methods");

# + [markdown] heading_collapsed=true
# ## Firing rates

# + [markdown] hidden=true
# We want Poisson firing, i.e. ISIs with an exponential distribution.  
# Firing rates lognormally distributed (instead of all the same, as before).

# + hidden=true
"""
`μ` and `σ` are mean and standard deviation of the underlying Gaussian.
`μₓ` is the mean of the log of the Gaussian.
"""
function LogNormal_with_mean(μₓ, σ)
    μ = log(μₓ) - σ^2 / 2
    LogNormal(μ, σ)
end;

# + hidden=true
# Mean and variance from Roxin2011 (cross checked with its refs Hromádka, O'Connor).
input_spike_rate = LogNormal_with_mean(4, √0.6)  # (Hz, dimensionless)

# + hidden=true
roxin = LogNormal_with_mean(5, √1.04)

# + hidden=true
gauss_variance = σ² = (σ_X, μ_X) -> log(1 + σ_X^2 / μ_X^2)
gauss_variance(7.4, 12.6)  # for oconnor

# + hidden=true
oconnor = LogNormal_with_mean(7.4, √0.3)

# + hidden=true
# Define probability distributions on unitful quantities.
# Distributions.pdf(d, x::Quantity) = pdf(d, ustrip(x)) / unit(x)
# Distributions.cdf(d, x::Quantity) = cdf(d, ustrip(x))

# + hidden=true
fig, (ax1, ax2, ax3) = plt.subplots(ncols=3, figsize=(8, 2.2))

rlin = (0:0.01:15)Hz
rlog = exp10.(-2:0.01:2)Hz
function plot_firing_rate_distr(distr; kw...)
    plot(rlin, pdf.(distr, rlin), ax1; clip_on=false, kw...)
    plot(rlog, pdf.(distr, rlog), ax2; clip_on=false, xscale="log", kw...)
    plot(rlin, cdf.(distr, rlin), ax3; clip_on=false, ylim=(0,1), kw...)
end

plot_firing_rate_distr(roxin, label="Roxin", c=lighten(C2, 0.6))
plot_firing_rate_distr(oconnor, label="O'Connor", c=lighten(C1, 0.6))
plot_firing_rate_distr(input_spike_rate, label="this study", c=C0, lw=2.7)

set(ax1; xlabel="Input firing rate", ytickstyle=:range)
set(ax2; ytickstyle=:range)
# set(ax3; yminorticks=false)
legend(ax3)
ylabel(ax1, "Probability density", dx=-52.8)
ylabel(ax3, "Cumulated probability", dx=-18)
ax2.set_xlabel("(log)", loc="center")
plt.tight_layout(w_pad=-2.3)

save("log-normal.pdf")

# + hidden=true
distrs = [oconnor, roxin, input_spike_rate]
DataFrame(
    σ=getfield.(distrs, :σ),
    mean=mean.(distrs),
    median=median.(distrs),
    std=std.(distrs),
    var=var.(distrs),
)
# -

# ## .

Nunconn = 100
Nexc    = 5200
Ninh    = Nexc ÷ 4

Ninh + Nexc

using DataStructures: PriorityQueue
using Unitful: Time

# +
λ = rand(input_spike_rate, Nexc)  # Hz
exps = Exponential.(λ)  # Hz
first_spiketimes = rand.(exps) * second

pq = PriorityQueue{Int, Time}()
for (i, t) in enumerate(first_spiketimes)
    enqueue!(pq, i => t)
end

sim_duration = 10*second;
selected_spiker = argmin(first_spiketimes)
t = 0.0*second
ts = Vector{typeof(t)}()
while t < sim_duration
    i, t = dequeue_pair!(pq)  # earliest spike
    new_ISI = rand(exps[i]) * second
    enqueue!(pq, i => t + new_ISI)
    if i == selected_spiker
        push!(ts, t)
    end
end
# -

using OrdinaryDiffEq
using ComponentArrays
using Parameters
using Unitful: nS, pF, pA

# +
@with_kw struct IzhikevichParams
    C = 100 * pF
    k = 0.7 * (nS/mV)
    b = -2 * nS
    v_r    = -60 * mV
    v_t    = -40 * mV
    v_peak =  35 * mV
    c      = -50 * mV
    a = 0.03 / ms
    d = 100 * pA
end
cortical_RS = IzhikevichParams();

τ_syn = 7 * ms;

# +
function f(D, vars, params, t)
    @unpack C, k, b, v_r, v_t, v_peak, c, a, d = params
    @unpack v, u = vars
    D.v = (k * (v - v_r) * (v - v_t) - u) / C
    D.u = a * (b * (v - v_r) - u)
    D.g = -g / τ_syn
    return nothing
end

x0 = ComponentArray(v = -80.0mV, u = 0.0pA)
prob = ODEProblem(f, x0, float(sim_duration), cortical_RS)
Δt = 0.1ms
integrator = init(prob, Tsit5(); Δt, adaptive=true)
# -

t = 0ms:0.1ms:sim_duration
v = t -> sol(t).v / mV |> NoUnits
plot(t, v.(t));
