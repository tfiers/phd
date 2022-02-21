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
#     display_name: Julia 1.7.0
#     language: julia
#     name: julia-1.7
# ---

# # 2022-02-20 • Fixed timestep Euler solver in vanilla Julia

# i.e. no `DifferentialEquations.jl`.
#
# Hopefully this achieves better performance.

# ## Setup

# +
# using Pkg; Pkg.resolve()
# -

using Revise


using Distributions

using MyToolbox

using VoltageToMap

# ## Parameters

# +
@kwdef struct PoissonInputParams
    N_unconn  ::Int          = 100
    N_exc     ::Int          = 5200
    N_inh     ::Int          = N_exc ÷ 4
    N_conn    ::Int          = N_inh + N_exc
    N         ::Int          = N_conn + N_unconn
    spike_rate::Distribution = LogNormal_with_mean(4Hz, √0.6)  # (μₓ, σ)
end

const realistic_input = PoissonInputParams()
const slightly_smaller_input = PoissonInputParams(N_exc = 800)
const small_N__as_in_Python_2021 = PoissonInputParams(N_unconn = 9, N_exc = 17)
small_N__as_in_Python_2021.N

# +
@kwdef struct SynapseParams
    g_t0     ::Float64   =     0   * nS
    τ_s      ::Float64   =     7   * ms
    E_exc    ::Float64   =     0   * mV
    E_inh    ::Float64   =  - 65   * mV
    Δg_exc   ::Float64   =     0.4 * nS
    Δg_inh   ::Float64   =     1.6 * nS
end

const semi_arbitrary_synaptic_params = SynapseParams();

# +
@kwdef struct IzhNeuronParams
    v_t0     ::Float64   = - 80    * mV
    u_t0     ::Float64   =    0    * pA
    C        ::Float64   =  100    * pF
    k        ::Float64   =    0.7  * (nS/mV)     # steepness of dv/dt's parabola
    vr       ::Float64   = - 60    * mV          # resting v
    vt       ::Float64   = - 40    * mV          # ~spiking thr
    a        ::Float64   =    0.03 / ms          # reciprocal of `u`'s time constant
    b        ::Float64   = -  2    * nS          # how strongly `(v - vr)` increases `u`
    v_peak   ::Float64   =   35    * mV          # cutoff to define spike
    v_reset  ::Float64   = - 50    * mV          # ..on spike. `c` in Izh.
    Δu       ::Float64   =  100    * pA          # ..on spike. `d` in Izh. Free parameter.
end

const cortical_RS = IzhNeuronParams();
# -

Base.@kwdef struct SimParams
    sim_duration  ::Float64            = 1.2 * seconds
    Δt            ::Float64            = 0.1 * ms
    poisson_input ::PoissonInputParams = realistic_input
    synapses      ::SynapseParams      = semi_arbitrary_synaptic_params
    izh_neuron    ::IzhNeuronParams    = cortical_RS
    Δg_multiplier ::Float64            = 1.0      # Free parameter, fiddled with until medium number of output spikes.
end;


# ## Simulation

function sim(params::SimParams)

    @unpack sim_duration, Δt, Δg_multiplier                      = params
    @unpack N_unconn, N_exc, N_inh, N_conn, N, spike_rate        = params.poisson_input
    @unpack E_exc, E_inh, g_t0, τ_s, Δg_exc, Δg_inh              = params.synapses
    @unpack v_t0, u_t0, C, k, vr, vt, a, b, v_peak, v_reset, Δu  = params.izh_neuron

    input_neuron_IDs = idvec(conn = idvec(exc = N_exc, inh = N_inh), unconn = N_unconn)
    synapse_IDs      = idvec(exc = N_exc, inh = N_inh)

    # Connections
    postsynapses = Dict{Int, Vector{Int}}()  # input_neuron_ID => [synapse_IDs...]
    for (n, s) in zip(input_neuron_IDs.conn, synapse_IDs)
        postsynapses[n] = [s]
    end
    for n in input_neuron_IDs.unconn
        postsynapses[n] = []
    end

    # Broadcast scalar parameters
    Δg = similar(synapse_IDs, Float64)
    Δg.exc .= Δg_multiplier * Δg_exc
    Δg.inh .= Δg_multiplier * Δg_inh
    E = similar(synapse_IDs, Float64)
    E.exc .= E_exc
    E.inh .= E_inh

    # Inter-spike—interval distributions
    λ = similar(input_neuron_IDs, Float64)
    λ .= rand(spike_rate, length(λ))
    β = 1 ./ λ
    ISI_distributions = Exponential.(β)
    first_input_spike_t = rand.(ISI_distributions)
    upcoming_input_spikes = PriorityQueue{Int, Float64}()
    for (neuron_ID, spike_t) in zip(input_neuron_IDs, first_input_spike_t)
        enqueue!(upcoming_input_spikes, neuron_ID => spike_t)
    end
    next_input_spike_t = peek(upcoming_input_spikes).second  # (`.first` is neuron ID).

    # Initialize simulation vars and their derivatives
    v = v_t0
    u = u_t0
    g = similar(synapse_IDs, Float64)
    g .= g_t0
    dv = zero(v)
    du = zero(u)
    dg = zero(g)

    t = zero(sim_duration)
    num_timesteps = round(Int, sim_duration / Δt)  # Fixed timestep
    v_rec = Vector{Float64}(undef, num_timesteps)
    input_spike_t_rec = similar(input_neuron_IDs, Vector{Float64})
    for i in eachindex(input_spike_t_rec)
        input_spike_t_rec[i] = Vector{Float64}()
    end

    # Solver loop.
    @showprogress 200ms for i in 1:num_timesteps

        # Sum synaptic currents
        I_s = zero(u)
        for (gi, Ei) in zip(g, E)
            I_s += gi * (v - Ei)
        end

        # Differential equations
        dv = (k * (v - vr) * (v - vt) - u - I_s) / C
        du = a * (b * (v - vr) - u)
        for i in 1:length(g)
            dg[i] = -g[i] / τ_s
        end

        # Euler integration
        v += dv * Δt
        u += du * Δt
        for i in 1:length(g)
            g[i] = dg[i] * Δt
        end

        # Izhikevich neuron spiking threshold
        if v ≥ v_peak
            v = v_reset
            u += Δu
        end

        # Record membrane voltage
        v_rec[i] = v

        # Input spikes
        t += Δt
        if t ≥ next_input_spike_t
            fired_neuron = dequeue!(upcoming_input_spikes)
            push!(input_spike_t_rec[fired_neuron], t)
            for synapse in postsynapses[fired_neuron]
                g[synapse] += Δg[synapse]
            end
            new_spike_time = t + rand(ISI_distributions[fired_neuron])
            enqueue!(upcoming_input_spikes, fired_neuron => new_spike_time)
            next_input_spike_t = peek(upcoming_input_spikes).second
        end
    end
    
    return (
        t = linspace(zero(t), t, num_timesteps),
        v = v_rec,
        input_spikes = input_spike_t_rec
    )
end

p = SimParams(poisson_input = small_N__as_in_Python_2021, Δg_multiplier = 300)
dump(p)

t, v, input_spikes = @time sim(p);

length.(input_spikes)
