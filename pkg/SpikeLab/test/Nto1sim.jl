using SpikeLab
using SpikeLab: SpikingInput, SpikeFeed, CVector, SimState
using SpikeLab.Units

izh!(D, (;v, u, gₑ, gᵢ, C, Eᵢ, Eₑ, a, b, k, vᵣ, vₗ, vₜ, τ)) = begin
    # Conductance-based synaptic current
    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)
    # Izhikevich 2D system: v and adaptation
    D.v = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C
    D.u = a*(b*(v-vᵣ) - u)
    # Synaptic conductance decay
    # (gₑ is sum over all exc synapses)
    D.gₑ = -gₑ / τ
    D.gᵢ = -gᵢ / τ
end
has_spiked((;v, vₛ)) = (v ≥ vₛ)
on_self_spike!(vars, (;vᵣ, Δu)) = begin
    vars.v = vᵣ
    vars.u += Δu
end
# Params
Nₑ = 40  # Number of excitatory Poisson inputs.
Nᵢ = 10
params = (
    C  =  100    * pF,
    k  =    0.7  * (nS/mV),
    vₗ = - 60    * mV,
    vₜ = - 40    * mV,
    a  =    0.03 / ms,
    b  = -  2    * nS,
    vₛ =   35    * mV,
    vᵣ = - 50    * mV,
    Δu =  100    * pA,
    # Synapses,
    Eₑ =   0 * mV,
    Eᵢ = -80 * mV,
    τ  =   7 * ms,
    # Inputs,
    Δgₑ = 60nS / Nₑ,
    Δgᵢ = 60nS / Nᵢ,
)
init = (
    v  = params.vᵣ,
    u  = 0 * pA,
    gₑ = 0 * nS,
    gᵢ = 0 * nS,
    I_syn = 0 * nA,
)
Δt = 0.1ms
T  = 10seconds
# Poisson inputs firing rate: distribution Λ and samples λ.
Λ = SpikeLab.LogNormal(median = 4Hz, g = 2)
λ = CVector{Float64}(exc = 1:Nₑ, inh = 1:Nᵢ)
λ .= rand(Λ, length(λ))
# On-spike-arrival functions:
fₑ!(vars, (;Δgₑ)) = (vars.gₑ += Δgₑ)
fᵢ!(vars, (;Δgᵢ)) = (vars.gᵢ += Δgᵢ)
inputs = similar(λ, SpikingInput)
inputs.exc .= poisson_input.(λ.exc, T, fₑ!)
inputs.inh .= poisson_input.(λ.inh, T, fᵢ!)

m = Model(izh!, has_spiked, on_self_spike!, inputs)
# s = sim(m, init, params, T, Δt)
s = init_sim(init, params, T, Δt)
s = step!(s, m)
