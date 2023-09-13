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
    plotsig(sim_ceil.V / mV, tlim, ms, label=".. with ceiled spikes"; ax, marker, kw...);
    plotsig(sim.V / mV, tlim, ms, label="Original simulation"; ax, marker, kw...);
    # legend(ax, reorder=[1=>2]);
end

fig, axs = plt.subplots(ncols=2, figsize=(mtw, 0.4*mtw), sharey=true)
ceilplot(tlim = [0, 1000], ax=axs[0], hylabel="Membrane voltage (mV)");
ceilplot(tlim = [50.56, 51.6], marker=".", ax=axs[1], hylabel=L"[zoomed in on $1^{\mathrm{st}}$ spike]");
axis = axs[1].xaxis
t = mpl.ticker
axis.set_minor_locator(t.MultipleLocator(0.1))
# rm_ticks_and_spine(axs[1], "left")
l = axs[0].get_lines()
plt.figlegend(handles=[l[1], l[0]], ncols=2, loc="lower center", bbox_to_anchor=(0.5, 1))
plt.tight_layout();
# -

# - [ ] Put legend in right axes? (move spike left, eg)
# - [ ] Call it 'Unmodified sim'?

t = sim.spiketimes[1]
t / ms

# +
(; Δt, Eₑ, Eᵢ, Δₜ, Vₜ, gₗ, Eₗ, C) = Nto1AdEx

i = round(Int, t/Δt)  # The spiketime `t` is one sample after where we want, but this i is correct

# +
n = sim.recording[i]

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
n = sim.recording[i-1]

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

savefig_phd("ceil_spikes", fig)
