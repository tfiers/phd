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

# # 2022-10-24 • N-to-1 with lognormal inputs (for real now)

# ## Imports

# +
#
# -

using MyToolbox

@time @time_imports using VoltoMapSim;  # after precompile & w/o touching src files

@time @time_imports using VoltoMapSim;  # with precompile on



@time @time_imports using VoltoMapSim;  # no showprogress, match

@time @time_imports using VoltoMapSim;  # no showprogress, match

@time @time_imports using VoltoMapSim;  # after vtms cleanup





using ProfileView, SnoopCompile

tinf = @snoopi_deep (using VoltoMapSim);

ProfileView.view(flamegraph(tinf), windowname="snoopcompile");







# ## Differential equations

izh = @eqs begin
    
    dv/dt = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C
    du/dt = a*(b*(v-vᵣ) - u)

    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    dgₑ/dt = -gₑ / τ  # Represents sum over all exc synapses
    dgᵢ/dt = -gᵢ / τ
end

# ## Parameters

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
);

# ## Init buffers

init = (
    v  = params.vᵣ,
    u  = 0 * pA,
    gₑ = 0 * nS,
    gᵢ = 0 * nS,
    I_syn = 0 * nA,
)
vars = CVec{Float64}(init)
diff = similar(vars)
diff .= 0

init.gᵢ += w

showsome(poisson_spikes(4Hz, 10minutes))

izh.generated_func

# +
# izh.f(diff, vars, params)
# -


