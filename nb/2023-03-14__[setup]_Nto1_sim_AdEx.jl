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
#     display_name: Julia 1.9.0-beta3
#     language: julia
#     name: julia-1.9
# ---

# # 2023-03-14 • [setup] N-to-1 simulation of AdEx neuron

# This is a script, to be 'imported' (included, run) by other notebooks.

# Based on `2023-02-07__AdEx_Nto1`.

# cd(joinpath(homedir(), "phd", "pkg" , "SpikeWorks"))
# run(`git switch metdeklak`)
# ↪ Not doing here, as multiprocs on same git repo crashes

using WithFeedback
@withfb using Distributed
@withfb using Revise
@withfb using SpikeWorks
@withfb using SpikeWorks.Units
@withfb using ConnectionTests
@withfb using DataFrames

@typed begin
    # AdEx LIF neuron params (cortical RS)
    C  = 104  * pF
    gₗ = 4.3  * nS
    Eₗ = -65  * mV
    Vₜ = -52  * mV
    Δₜ = 0.8  * mV
    Vₛ =   0  * mV
    Vᵣ = -53  * mV
    a  = 0.8  * nS
    b  =  65  * pA
    τw =  88  * ms
    # Conductance-based synapses
    Eₑ =   0 * mV
    Eᵢ = -80 * mV
    τ  =   7 * ms
end

# -
# ### Simulated variables and their initial values

const x₀ = (
    # AdEx variables
    v   = Vᵣ,      # Membrane potential
    w   = 0 * pA,  # Adaptation current
    # Synaptic conductances g
    gₑ  = 0 * nS,  # = Sum over all exc. synapses
    gᵢ  = 0 * nS,  # = Sum over all inh. synapses
)

# ### Differential equations:
# calculate time derivatives of simulated vars
# (and store them "in-place", in `Dₜ`).

function f!(Dₜ, vars)
    v, w, gₑ, gᵢ = vars

    # Conductance-based synaptic current
    Iₛ = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    # AdEx 2D system
    Dₜ.v = (-gₗ*(v-Eₗ) + gₗ*Δₜ*exp((v-Vₜ)/Δₜ) - Iₛ - w) / C
    Dₜ.w = (a*(v-Eₗ) - w) / τw

    # Synaptic conductance decay
    Dₜ.gₑ = -gₑ / τ
    Dₜ.gᵢ = -gᵢ / τ
end

# ### Spike discontinuity

has_spiked(vars) = (vars.v > Vₛ)

function on_self_spike!(vars)
    vars.v = Vᵣ
    vars.w += b
end
# -

# ### Conductance-based AdEx neuron

const coba_adex_neuron = NeuronModel(x₀, f!; has_spiked, on_self_spike!);


# ### More parameters, and input spikers

using SpikeWorks: LogNormal

# Firing rates λ for the Poisson inputs
const fr_distr = LogNormal(median = 4Hz, g = 2)

@typed begin
    Δt = 0.1ms
    EIratio = 4//1
end

using SpikeWorks: newsim, run!

using Random

function run_Nto1_AdEx_sim(; N, duration, seed, δ_nS)
    # δ_nS: Strength, in nS, of each incoming spike:
    #       How much does it increase the postsynaptic conductance, g.
    Random.seed!(seed)
    firing_rates = rand(fr_distr, N)
    input_IDs = 1:N
    inputs = [
        Nto1Input(ID, poisson_SpikeTrain(λ, duration))
        for (ID, λ) in zip(input_IDs, firing_rates)
    ]
    (; Nₑ, Nᵢ) = EIMix(N, EIratio)
    neuron_type(ID) = (ID ≤ Nₑ) ? :exc : :inh
    Δgₑ = δ_nS * nS
    Δgᵢ = δ_nS * nS * EIratio
    on_spike_arrival!(vars, spike) =
        if neuron_type(source(spike)) == :exc
            vars.gₑ += Δgₑ
        else
            vars.gᵢ += Δgᵢ
        end

    sim = newsim(coba_adex_neuron, inputs, on_spike_arrival!, Δt)
    run!(sim)

    _spiketimes(input::Nto1Input) = input.train.spiketimes

    # The names of this NamedTuple are the API.
    # They are stable/versioned.
    # The weirdness on the RHS is opaque.
    simdata = (;
        spiketrains   = _spiketimes.(inputs),
        voltsig       = sim.rec.v,
        spikerate     = SpikeWorks.spikerate(sim),
        input_types   = neuron_type.(input_IDs),
        sim_duration  = duration,
        firing_rates, input_IDs, N, seed, δ_nS
    )
    return simdata
end

# An alias for human readability.
# We don't make it a proper (concrete) type, as we want to be able to
# change it, without having to restart Julia.
const SimData = NamedTuple

"Spiking rate of the output neuron in an Nto1 sim"
spikerate(sd::SimData) = sd.spikerate

"Voltage signal of the output neuron in an Nto1 sim"
voltsig(sd::SimData) = sd.voltsig

"List of spiketime-lists"
spiketrains(sd::SimData) = sd.spiketrains

"Neuron type (exc or inh) of each input spiker"
input_types(sd::SimData) = sd.input_types



# --- Caching ---

@withfb using MemDiskCache

dir = "2023-03-14__Nto1_AdEx_sims"
sims = CachedFunction(run_Nto1_AdEx_sim; dir)

println("Warming up sim & JLD2 funcs")
# For multiproccessing: every
kw = (; N=5, δ_nS=5.0, duration=1seconds, seed=100+myid())
rm_from_disk(sims; kw...)
sims(; kw...)
rm_from_memcache!(sims; kw...)
sims(; kw...)
println(" … done")



# ---

gen_unconnected_trains(sd::SimData, num; seed = 1) = begin
    Random.seed!(seed)
    firing_rates = rand(fr_distr, num)
    T = sd.sim_duration
    trains = [SpikeWorks.poisson_spikes(r, T) for r in firing_rates]
end

conntest_all(sd::SimData, method; N_unconn) = begin
    v = voltsig(sd)
    trains_conn = spiketrains(sd)
    trains_unconn = gen_unconnected_trains(sd, N_unconn)
    trains = [
        trains_conn...,
        trains_unconn...,
    ]
    conntypes = [
        input_types(sd)...,
        fill(:unc, N_unconn)...,
    ]
    rows = []
    for (train, conntype) in zip(trains, conntypes)
        spikerate = length(train) / sd.sim_duration
        t = test_conn(method, v, train)
        push!(rows, (; spikerate, conntype, t))
    end
    return DataFrame(rows)
end
