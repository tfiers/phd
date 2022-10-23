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

@time_imports using VoltoMapSim

# ## Differential equations

izh = @eqs begin
    
    dv/dt = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C
    du/dt = a*(b*(v-vᵣ) - u)

    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    dgₑ/dt = -gₑ / τ  # Represents sum over all exc synapses
    dgᵢ/dt = -gᵢ / τ
end;

izh

izh.generated_func

# ## Initialize buffers

# +
params = (
    # Cortical regular spiking (same as always)
    C  =  100    * pF,
    k  =    0.7  * (nS/mV),
    vₗ = - 60    * mV,
    vₜ = - 40    * mV,
    a  =    0.03 / ms,
    b  = -  2    * nS,
    # Not in model eqs above (yet)
    vₛ =   35    * mV,  # spike
    vᵣ = - 50    * mV,  # reset
    Δu =  100    * pA,

    # Synapses
    Eₑ =   0 * mV,
    Eᵢ = -80 * mV,  # Higher than Nto1 (was -65); same as nets.
    τ  =   7 * ms,
)

init = (
    v  = params.vᵣ,
    u  = 0 * pA,
    gₑ = 0 * nS,
    gᵢ = 0 * nS,
    I_syn = 0 * nA,
);
# -

vars = CVec{Float64}(init)
diff = similar(vars)
diff .= 0


duration = 1 * second
Δt       = 0.1 * ms
Nt = to_timesteps(duration, Δt)

for ti in 1:Nt
    izh.f(diff, vars, params)
    vars .+= diff .* Δt
end

Revise.revise(SpikeLab);
Revise.revise(VoltoMapSim);

poisson_spikes(5Hz, 20minutes)

?poisson_spikes

# Pause for now, and continue with the science.
