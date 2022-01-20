# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.6
#   kernelspec:
#     display_name: Julia 1.7.1
#     language: julia
#     name: julia-1.7
# ---

# # 2022-01-08 • 1000-to-1

using Revise
using Unitful
using Unitful: Hz, s, ms
using Distributions

λ = 3Hz
θ = 1/λ |> s
d = Exponential(θ)

T = typeof(d)
fit_mle(T, suffstats(T, [3s, 1s, 1s], float([1,1,1])))





include("nb_init.jl");

save(fname) = savefig(fname, subdir="methods");

# ## Firing rates

# We want Poisson firing, i.e. ISIs with an exponential distribution.  
# Firing rates lognormally distributed (instead of all the same, as before).

"""
`μ` and `σ` are mean and standard deviation of the underlying Gaussian.
`μₓ` is the mean of the log of the Gaussian.
"""
function LogNormal_with_mean(μₓ, σ)
    μ = log(μₓ / unit(μₓ)) - σ^2 / 2
    LogNormal(μ, σ)
end;

# Mean and variance from Roxin2011 (cross checked with its refs Hromádka, O'Connor).
input_spike_rate = LogNormal_with_mean(4Hz, √0.6)

roxin = LogNormal_with_mean(5Hz, √1.04)

σ² = (σ_X, μ_X) -> log(1 + σ_X^2 / μ_X^2)
σ²_oconnor = σ²(7.4Hz, 12.6Hz)

oconnor = LogNormal_with_mean(7.4Hz, √σ²_oconnor)

# +
fig, (ax1, ax2, ax3) = plt.subplots(ncols=3, figsize=(8, 2.2))

rlin = (0:0.01:15) * Hz
rlog = (log10(0.04):0.01:log10(41) .|> exp10) * Hz
function plot_firing_rate_distr(distr; kw...)
    plot(rlin, pdf.(distr, rlin), ax1; clip_on=false, kw...)
    plot(rlog, pdf.(distr, rlog), ax2; clip_on=false, xscale="log", kw...)
    plot(rlin, cdf.(distr, rlin), ax3; clip_on=false, ylim=(0,1), kw...)
end

plot_firing_rate_distr(roxin, label="Roxin", c=lighten(C2, 0.4))
plot_firing_rate_distr(oconnor, label="O'Connor", c=lighten(C1, 0.4))
plot_firing_rate_distr(input_spike_rate, label="This study", c=C0, lw=2.7)

set(ax1; xlabel="Input firing rate", ytickstyle=:range, hylabel="Probability density")
set(ax2; xlabel=("(log scale)", :loc=>:center), yaxis=:off)
set(ax3; hylabel="Cumulative probability")
deemph(:yaxis, ax1)
legend(ax2, loc="center", bbox_to_anchor=(-0.14, 0.7), reorder=[3=>1])
ax2.get_legend().set_in_layout(false)
plt.tight_layout(w_pad=1)

save("log-normal.pdf")
# -

distrs = [oconnor, roxin, input_spike_rate]
DataFrame(
    name=["oconnor", "roxin", "this study"],
    σ=getfield.(distrs, :σ),
    mean=mean.(distrs),
    median=median.(distrs),
    std=std.(distrs),
    var=var.(distrs),
) |> printsimple

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
t = 0.0*second
while t < sim_duration
    i, t = dequeue_pair!(pq)  # earliest spike
    new_ISI = rand(exps[i]) * second
    enqueue!(pq, i => t + new_ISI)
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
