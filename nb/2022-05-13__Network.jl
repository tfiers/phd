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

# # 2022-05-13 • A Network

# Every timestep, simulate a list of neurons.

# ## Imports

# +
#
# -

using Revise

using MyToolbox

using VoltageToMap

# ## Params

# We need to mark every variable as constant, otherwise simulation is slow. (See Julia manual > performance tips, first and second points).

const rngseed = 22022022;


#  PoissonInputParams
const N_unconn           = 100
const N_exc              = 5200
const N_inh              = N_exc ÷ 4
const N_conn             = N_inh + N_exc
const N                  = N_conn + N_unconn
const spike_rates        = LogNormal_with_mean(4Hz, √0.6)  # (μₓ, σ);

#  SynapseParams
const avg_stim_rate_exc  =    0.1 * nS / seconds
    # Used to calculate the postsynaptic conductance increase per spike for all
    # excitatory neurons, by dividing by the mean of the spike rate distribution
    # (defined above).
const avg_stim_rate_inh  =    0.4 * nS / seconds
const E_exc              =    0   * mV   # Reversal potentials
const E_inh              = - 65   * mV   #
const g_t0               =    0   * nS   # Conductances at `t = 0`
const τ                  =    7   * ms   # Time constant of exponential decay of conductances;

#  IzhikevichParams
const C        =  100    * pF          # cell capacitance
const k        =    0.7  * (nS/mV)     # steepness of dv/dt's parabola
const v_rest   = - 60    * mV          # resting v
const v_thr    = - 40    * mV          # ~spiking thr
const a        =    0.03 / ms          # reciprocal of `u`'s time constant
const b        = -  2    * nS          # how strongly `(v - v_rest)` increases `u`
const v_peak   =   35    * mV          # cutoff to define spike
const v_reset  = - 50    * mV          # Reset after spike. `c` in Izh.
const Δu       =  100    * pA          # Increase on spike. `d` in Izh. Free parameter.
const v_t0     = v_rest
const u_t0     =    0    * pA;

#  VoltageImagingParams
const spike_SNR      = 10
const spike_SNR_dB   = 20log10(spike_SNR)   # 1 ⇒ 0dB,  10 ⇒ 20dB,  100 ⇒ 40dB,  …
const spike_height   = v_peak - v_rest
const σ_noise        = spike_height / spike_SNR;

#  SimParams
const duration       = 10 * seconds
const Δt             = 0.1 * ms
const num_timesteps  = round(Int, duration / Δt);

#  ConnTestParams
const STA_window_length     = 100 * ms
const num_shuffles          = 100
const STA_test_statistic    = "mean";

#  EvaluationParams
const α = 0.05   # p-value threshold / false detection rate;

# ## Init sim

# IDs, subgroup names.
const input_neuron_IDs = idvec(conn = idvec(exc = N_exc, inh = N_inh), unconn = N_unconn)
const synapse_IDs      = idvec(exc = N_exc, inh = N_inh)
const var_IDs          = idvec(t = nothing, v = nothing, u = nothing, g = similar(synapse_IDs));

resetrng!(rngseed);

# Inter-spike—interval distributions
const λ = similar(input_neuron_IDs, Float64)
λ .= rand(spike_rates, length(λ))
const β = 1 ./ λ
const ISI_distributions = Exponential.(β);

# Input spikes queue
const first_input_spike_times = rand.(ISI_distributions)
const upcoming_input_spikes   = PriorityQueue{Int, Float64}()
for (n, t) in zip(input_neuron_IDs, first_input_spike_times)
    enqueue!(upcoming_input_spikes, n => t)
end;

# Connections
const postsynapses = Dict{Int, Vector{Int}}()  # input_neuron_ID => [synapse_IDs...]
for (n, s) in zip(input_neuron_IDs.conn, synapse_IDs)
    postsynapses[n] = [s]
end
for n in input_neuron_IDs.unconn
    postsynapses[n] = []
end;

# Broadcast scalar parameters
const Δg = similar(synapse_IDs, Float64)
Δg.exc .= avg_stim_rate_exc / mean(spike_rates)
Δg.inh .= avg_stim_rate_inh / mean(spike_rates)
const E = similar(synapse_IDs, Float64)
E.exc .= E_exc
E.inh .= E_inh;

# Allocate memory to be overwritten every simulation step;
# namely for the simulated variables and their time derivatives.
const vars = similar(var_IDs, Float64)
vars.t = zero(duration)
vars.v = v_t0
vars.u = u_t0
vars.g .= g_t0
const diff = similar(vars)  # = ∂x/∂t for every x in `vars`
diff.t = 1 * s/s;

# Where to record to
const v_rec = Vector{Float64}(undef, num_timesteps)
const input_spikes = similar(input_neuron_IDs, Vector{Float64})
for i in eachindex(input_spikes)
    input_spikes[i] = Vector{Float64}()
end;

# ## Run sim

function step_sim(i)

    @unpack t, v, u, g = vars

    # Sum synaptic currents
    I_s = zero(u)
    for (gi, Ei) in zip(g, E)
        I_s += gi * (v - Ei)
    end

    # Differential equations
    diff.v = (k * (v - v_rest) * (v - v_thr) - u - I_s) / C
    diff.u = a * (b * (v - v_rest) - u)
    for i in eachindex(g)
        diff.g[i] = -g[i] / τ
    end

    # Euler integration
    @. vars += diff * Δt

    # Izhikevich neuron spiking threshold
    if v ≥ v_peak
        vars.v = v_reset
        vars.u += Δu
    end

    # Record membrane voltage
    v_rec[i] = v

    # Input spikes
    t_next_input_spike = peek(upcoming_input_spikes).second  # (.first is neuron ID).
    if t ≥ t_next_input_spike
        n = dequeue!(upcoming_input_spikes)  # ID of the fired input neuron
        push!(input_spikes[n], t)
        for s in postsynapses[n]
            g[s] += Δg[s]
        end
        tn = t + rand(ISI_distributions[n])  # Next spike time for the fired neuron
        enqueue!(upcoming_input_spikes, n => tn)
    end
    # Unhandled edge case: multiple spikes in the same time bin get processed with
    # increasing delay. (This problem goes away when using diffeq.jl, `adaptive`).
end;

x = progress_bar_update_interval = 400ms
@showprogress x for i in 1:num_timesteps
    step_sim(i)
end;

const t = linspace(zero(duration), duration, num_timesteps);

const vi = v_rec + randn(length(v_rec)) * σ_noise;


# ## Plot sim


# ## Conntest
