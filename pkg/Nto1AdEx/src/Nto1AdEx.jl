module Nto1AdEx

using GlobalMacros
using Units
using Random

@typed begin
    # AdEx LIF neuron params (cortical RS)
    C  = 104  * pF
    gₗ = 4.3  * nS
    Eₗ = -65  * mV
    Vₜ = -52  * mV
    Δₜ = 0.8  * mV
    Vₛ =  40  * mV
    Vᵣ = -53  * mV
    a  = -0.8 * nS
    b  =  65  * pA
    τw =  88  * ms
    # Conductance-based synapses
    Eₑ =   0 * mV
    Eᵢ = -80 * mV
    τg =   7 * ms
    wₑ =  14 * pS
    wᵢ =   4 * wₑ
    # Simulation timestep
    Δt = 0.1 * ms
    # Input firing rate distribution
    μₓ = 4 * Hz
    σ = sqrt(0.6)
    μ = log(μₓ / Hz) - σ^2 / 2
end

const T = Float64

@kwdef mutable struct Neuron
    V    ::T = Eₗ
    w    ::T = 0 * pA
    gₑ   ::T = 0 * nS
    gᵢ   ::T = 0 * nS
    DₜV  ::T = 0 * mV/second
    Dₜw  ::T = 0 * pA/second
    Dₜgₑ ::T = 0 * nS/second
    Dₜgᵢ ::T = 0 * nS/second
end

# Calculate & store derivatives
f!(n::Neuron) = let (; V, w, gₑ, gᵢ) = n
    # Synaptic current
    Iₛ = gₑ*(V - Eₑ) + gᵢ*(V - Eᵢ)
    # Diffeqs
    n.DₜV  = (-gₗ*(V - Eₗ) + gₗ*Δₜ*exp((V-Vₜ)/Δₜ) - Iₛ - w) / C
    n.Dₜw  = (a*(V - Eₗ) - w) / τw
    n.Dₜgₑ = -gₑ / τg
    n.Dₜgᵢ = -gᵢ / τg
end

eulerstep!(n::Neuron) = begin
    n.V  += n.DₜV  * Δt
    n.w  += n.Dₜw  * Δt
    n.gₑ += n.Dₜgₑ * Δt
    n.gᵢ += n.Dₜgᵢ * Δt
end

has_spiked(n::Neuron) = n.V > Vₛ
on_self_spike!(n::Neuron) = begin
    n.V = Vᵣ
    n.w += b
end

include("poisson.jl")

struct Spike
    time   ::Float64
    source ::Int
end
Base.isless(x::Spike, y::Spike) = x.time < y.time

spikevec(src_id, times) = [Spike(t, src_id) for t in times]

multiplex(spiketrains) = begin
    # Join spiketimes of different trains into one sorted stream of Spikes
    spikevecs = [spikevec(i, times) for (i, times) in enumerate(spiketrains)]
    spikes = reduce(vcat, spikevecs)
    sort!(spikes)
end

sim(N, duration, seed=1) = begin
    Random.seed!(seed)
    num_steps = round(Int, duration / Δt)
    t = 0 * second
    n = Neuron()
    V = Vector{T}(undef, num_steps)
    spiketimes = T[]
    Nₑ = round(Int, N * 4/5)
    rates = exp.(randn(N) .* σ .+ μ) .* Hz
    trains = [poisson_spikes(r, duration) for r in rates]
    spikes = multiplex(trains)
    # Index to keep track of input spikes processed
    j = 1
    for i in 1:num_steps
        # Process incoming spikes
        while j < length(spikes) && spikes[j].time < t
            # New spike arrival
            spike = spikes[j]
            if spike.source ≤ Nₑ
                n.gₑ += wₑ
            else
                n.gᵢ += wᵢ
            end
            j += 1
        end
        # Update neuron state variables (calc & apply diffeqs)
        f!(n)
        eulerstep!(n)
        if has_spiked(n)
            on_self_spike!(n)
            push!(spiketimes, t)
        end
        V[i] = n.V
        t += Δt
    end
    spikerate = length(spiketimes) / duration
    return (; V, spiketimes, rates, trains, Nₑ, spikerate)
end

end
