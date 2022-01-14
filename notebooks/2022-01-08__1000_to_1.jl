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

include("nb_init.jl");

save = savefig $ (; subdir="methods");

# ## Generate spikes

# We want Poisson firing, i.e. ISIs with an exponential distribution.  
# Firing rates lognormally distributed (instead of all the same, as before).

"""
`μ` and `σ` are mean and standard deviation of the underlying Gaussian.
`mean` is the mean of the log of the Gaussian.
"""
function LogNormal_with_mean(mean, σ)
    μ = log(mean) - σ^2 / 2
    LogNormal(μ, σ)
end;

# +
# Mean and variance from Roxin2011 (cross checked with its refs Hromádka, O'Connor).

input_spike_rate = LogNormal_with_mean(4, √(1.04))  # both in Hz
# -

# Define probability distributions on units.
Distributions.pdf(d, x::Quantity) = pdf(d, ustrip(x)) / unit(x)
Distributions.cdf(d, x::Quantity) = cdf(d, ustrip(x))

# +
fig, (ax1, ax2, ax3) = plt.subplots(ncols=3, figsize=(8, 2.2))

rlin = (0:0.01:15)Hz
rlog = exp10.(-2:0.01:2)Hz
function plot_firing_rate_distr(distr; kw...)
    plot(rlin, pdf.(distr, rlin), ax1; clip_on=false, label=f"σ = {distr.σ:.3g} Hz", kw...)
    plot(rlog, pdf.(distr, rlog), ax2; clip_on=false, label=f"σ = {distr.σ:.3g} Hz", xscale="log", kw...)
    plot(rlin, cdf.(distr, rlin), ax3; clip_on=false, label=f"σ = {distr.σ:.3g} Hz", ylim=(0,1), kw...)
end

plot_firing_rate_distr(LogNormal_with_mean(4, √1.8), c=lighten(C1, 0.6))
plot_firing_rate_distr(LogNormal_with_mean(4, √0.4), c=lighten(C2, 0.6))
plot_firing_rate_distr(input_spike_rate, c=C0, lw=2.7)

set(ax1; xlabel="Input firing rate", ytickstyle=:range)
set(ax2; ytickstyle=:range)
set(ax3; yminorticks=false)
legend(ax3, reorder=[3 => 2])
ylabel(ax1, "Probability density", dx=-52.8)
ylabel(ax3, "Cumulative probability", dy=6, dx=-18)
ax2.set_xlabel("(log)", loc="center")
plt.tight_layout(w_pad=-2.3)

save("lognormal.pdf")
# -

# They have the same mean. Reason is that the early risers also have heavier tails (even though you can't see it here).

N_exc    = 1600
N_inh    = 400
N_unconn = 100;





rand(input_spike_rate, N_exc) * Hz




