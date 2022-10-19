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

# ## .

izh = @eqs begin
    
    dv/dt = (k*(v-vᵣ)*(v-vₜ) - u - I_syn + I_ext) / C
    du/dt = a*(b*(v-vᵣ) - u)

    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    dgₑ/dt = -gₑ / τ  # Represents sum over all exc synapses
    dgᵢ/dt = -gᵢ / τ
    
    @spike if v > v_peak
        v = v_reset
        u += Δu
    end
end;

izh

izh.generated_func

show_eqs(izh)

vars = CVec{Float64}(v=0, u=0, I_syn=0, gₑ=0, gᵢ=0)
diff = similar(vars)
params = idvec(:C, :Eᵢ, :Eₑ, :I_ext, :a, :b, :k, :vᵣ, :vₜ, :τ)
params = similar(params, Float64)
params .= 1
izh.f(diff, vars, params)
diff

vars .+= diff * 0.1 #ms

vars

izh.f()

params_any = similar(params, Any)
params_any .= params
params_any.C = "wrongtype"
izh.f(diff, vars, params_any)

using Unitful: mV, nS

3mV
