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

Base.copy(n::Neuron) = Neuron((getfield(n, f) for f in fieldnames(Neuron))...)

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

const input_for_4Hz_output = Dict([
    (N = 10,  	we = 2.838843 * nS),
    (N = 20,  	we = 1.856241 * nS),
    (N = 45,  	we = 1.052897 * nS),
    (N = 100,  	we = 0.586951 * nS),
    (N = 200,  	we = 0.335195 * nS),
    (N = 400,  	we = 0.183884 * nS),
    (N = 800,  	we = 0.100299 * nS),
    (N = 1600,  we = 0.055847 * nS),
    (N = 3200,  we = 0.029046 * nS),
    (N = 6500,  we = 0.015036 * nS),  # = 15.036 pS, i.e. enough signif digits
])
# Source: https://tfiers.github.io/phd/nb/2023-08-05__AdEx_Nto1_we_sweep.html

sim(
    N,
    duration,
    seed = 1,
    wₑ = get(input_for_4Hz_output, N, 0.2*nS),
    wᵢ = 4*wₑ;
    ceil_spikes = false,
    record_all = false,
) = begin
    Random.seed!(seed)
    num_steps = round(Int, duration / Δt)
    t = 0 * second
    n = Neuron()
    V = Vector{T}(undef, num_steps)
    if record_all
        recording = Vector{Neuron}(undef, num_steps)
    else
        recording = nothing
    end
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
        if record_all
            recording[i] = copy(n)
        end
        t += Δt
    end
    if ceil_spikes
        ceil_spikes!(V, spiketimes)
    end
    spikerate = length(spiketimes) / duration

    # This NamedTuple is our implicitly defined 'simdata' data
    # structure, on which the functions below operate. It is what we
    # mean with `SimData` below.
    return (; V, spiketimes, rates, trains, duration, N, Nₑ, wₑ, wᵢ, spikerate, recording)
end

# Readability alias
const SimData = NamedTuple


function ceil_spikes!(V, spiketimes, V_ceil = Vₛ)
    i = round.(Int, spiketimes / Δt)
    V[i] .= V_ceil
    return V
end


struct SpikeTrain
    times  ::Vector{Float64}
    T      ::Float64            # = sim duration
end

Base.show(io::IO, s::SpikeTrain) =
    print(io, SpikeTrain, "(", num_spikes(s), " spikes, ",
              spikerate(s) / Hz, " Hz, ", s.times, ")")

num_spikes(s::SpikeTrain) = length(s.times)
spikerate(s::SpikeTrain) = num_spikes(s) / s.T

@doc (@doc poisson_spikes)
poisson_SpikeTrain(r, T) = SpikeTrain(poisson_spikes(r, T), T)

excitatory_inputs(s::SimData) = SpikeTrain.(s.trains[1:s.Nₑ], s.duration)
inhibitory_inputs(s::SimData) = SpikeTrain.(s.trains[s.Nₑ+1:end], s.duration)

highest_firing(trains::AbstractVector{SpikeTrain}) =
    sort(trains, by = spikerate, rev = true)


export SpikeTrain, num_spikes, spikerate, poisson_SpikeTrain
export excitatory_inputs, inhibitory_inputs, highest_firing
export Neuron
export ceil_spikes!

end
