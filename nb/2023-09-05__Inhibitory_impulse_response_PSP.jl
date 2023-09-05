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

# +
N = 1
EI_ratio = 0  # i.e. all inh
duration = 150 * ms
wₑ = 14 * pS
wᵢ = 4 * wₑ
input = [[10*ms]]

@time sim = Nto1AdEx.sim(N, duration; input, EI_ratio, record_all=true, wᵢ);
# -

include("lib/plot.jl")

# +
(; Eₑ, Eᵢ) = Nto1AdEx
(; gₑ, gᵢ, V, w) = sim.rec

Iₛ = @. gₑ*(V - Eₑ) + gᵢ*(V - Eᵢ);
# -

kw = (nbins_y=3, nbins_x=3, yaxloc=:right, clip_on=false, xunit=:ms)
figsize = (mw, 2.7*mw)
figsize = (1.4, 3.8)
fig, axs = plt.subplots(; figsize, nrows=4, sharex=true, dpi=400)
axs[1].axhline(c="black", lw=1)
plotsig(gᵢ, ms; hylabel=L"$g_\mathrm{inh}$", kw..., ax=axs[0], color="C2", yunit=:pS)
plotsig(-Iₛ, ms; hylabel=L"$-I_\mathrm{syn}$", kw..., ax=axs[1], yunit=:pA)
plotsig(V, ms; hylabel=L"$V$", kw..., ax=axs[2], yunit=:mV)
plotsig(w, ms; hylabel=L"$w$", kw..., ax=axs[3], yunit=:fA)
axs[-1].set_xlabel(nothing)
for ax in axs[0:2]
    ax.set_xlabel(nothing)
    ax.spines["bottom"].set_visible(false)
    ax.tick_params(bottom=false, which="both")
end
plt.subplots_adjust(hspace=1.2);

# Just to check our code Nto1AdEx.jl haven't impacted original sim:

@time simm = Nto1AdEx.sim(6500, 10*minutes);

plotsig(simm.V / mV, [0, 1000], ms);

simm.spiketimes[1] / ms

# All good.
