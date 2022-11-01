using SpikeLab: @eqs, PoissonInput, Model, sim
using SpikeLab: SpikingInput, SpikeFeed, CVector
using SpikeLab.Units

izh_generated = @eqs begin

    dv/dt = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C
    du/dt = a*(b*(v-vᵣ) - u)

    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    dgₑ/dt = -gₑ / τ  # Represents sum over all exc synapses
    dgᵢ/dt = -gᵢ / τ
end

function izh!(D; v, u, gₑ, gᵢ, C, Eᵢ, Eₑ, a, b, k, vᵣ, vₗ, vₜ, τ)

    I_syn = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    D.v = (k*(v-vₗ)*(v-vₜ) - u - I_syn) / C
    D.u = a*(b*(v-vᵣ) - u)

    D.gₑ = -gₑ / τ
    D.gᵢ = -gᵢ / τ
end

# Params
Nₑ = 40
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

has_spiked(; v, vₛ) = (v ≥ vₛ)
on_self_spike!(vars; vᵣ, Δu) = begin
    vars.v = vᵣ
    vars.u += Δu
end
Λ = SpikeLab.LogNormal(median = 4Hz, g = 2)
λ = CVector{Float64}(exc = 1:Nₑ, inh = 1:Nᵢ)
λ .= rand(Λ, length(λ))
# on-spike-arrival functions:
fₑ!(vars; Δgₑ) = (vars.gₑ += Δgₑ)
fᵢ!(vars; Δgᵢ) = (vars.gᵢ += Δgᵢ)
inputs = similar(λ, PoissonInput)
inputs.exc .= PoissonInput.(λ.exc, T, fₑ!)
inputs.inh .= PoissonInput.(λ.inh, T, fᵢ!)

m = Model(izh!, has_spiked, on_self_spike!, inputs)

sim(m, init, par T, Δt)
