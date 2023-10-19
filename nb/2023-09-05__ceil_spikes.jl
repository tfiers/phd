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
#     display_name: Julia 1.9.3
#     language: julia
#     name: julia-1.9
# ---

# # 2023-09-05 · Ceil spikes 

include("lib/Nto1.jl")

# +
N = 6500
duration = 10minutes

@time sim = Nto1AdEx.sim(N, duration, record_all=true, ceil_spikes=false);
# -

@time sim_ceil = Nto1AdEx.sim(N, duration, ceil_spikes=true);

include("lib/plot.jl")

# +
function ceilplot(; tlim, marker=nothing, ax, kw...)
    xkw = (xlabel=nothing, xunit_in=:last_ticklabel, ylim=[-80, 60])
    plotsig(sim_ceil.V / mV, tlim, ms, label="With ceiled spikes"; ax, marker, xlim=tlim, xkw..., kw...);
    plotsig(sim.V / mV, tlim, ms, label="Unmodified sim"; ax, marker, xlim=tlim, xkw..., kw...);
end

fig, axs = plt.subplots(ncols=2, figsize=(1.2*mtw, 0.45*mtw))
ceilplot(tlim = [0, 1000], ax=axs[0], hylabel="Membrane voltage (mV)");
ceilplot(tlim = [50.9, 52.5], marker=".", ax=axs[1], hylabel=L"[zoomed in on $1^{\mathrm{st}}$ spike]",
         xticklocs=[51, 51.5, 52, 52.5]);
# deemph_middle_ticks(axs[0])
# t = mpl.ticker
# axis = axs[1].xaxis
# axis.set_minor_locator(t.MultipleLocator(0.1))
legend(axs[1], reverse=true, fontsize=7.3, loc="center right")
rm_ticks_and_spine(axs[1], "left")
plt.tight_layout();
# -

# - [x] Put legend in right axes? (move spike left, eg)
# - [x] Call it 'Unmodified sim'?

savefig_phd("ceil_spikes", fig)

t = sim.spiketimes[1]
t / ms

# +
(; Δt, Eₑ, Eᵢ, Δₜ, Vₜ, gₗ, Eₗ, C) = Nto1AdEx

i = round(Int, t/Δt)  # The spiketime `t` is one sample after where we want, but this i is correct

# +
n = sim.rec[i]

(; V, gₑ, gᵢ, w) = n
V / mV

# +
Iₛ = gₑ*(V - Eₑ) + gᵢ*(V - Eᵢ)
DₜV  = (-gₗ*(V - Eₗ) + gₗ*Δₜ*exp((V-Vₜ)/Δₜ) - Iₛ - w) / C

V_new = V + Δt * DₜV
V_new / mV
# -

V_new / volt

DₜV

n.DₜV

# So yeah, why the discrep here.

# "Ah, it's cause the n.V is what we get _after_ calculating n.DₜV, in simcode. Whereas here, we re-used that V. We'd get same result if we do our calc here with (V,w,g) values of prev i"

# +
n = sim.rec[i-1]

(; V, gₑ, gᵢ, w) = n
V / mV

# +
Iₛ = gₑ*(V - Eₑ) + gᵢ*(V - Eᵢ)
DₜV  = (-gₗ*(V - Eₗ) + gₗ*Δₜ*exp((V-Vₜ)/Δₜ) - Iₛ - w) / C

V_new = V + Δt * DₜV
V_new / mV
# -

# Yeah, okay. :)

# ("Exp grows fast!")
