"""
Fixed parameters used in the simulation, connection tests, and performance evaluation; and
their default values.

`@deftype` is a macro from Parameters.jl that defines every field to have the specified type
(unless overridden) -- to avoid repetition.
"""


@with_kw struct PoissonInputParams
    N_unconn     ::Int            = 100
    N_exc        ::Int            = 5200
    N_inh        ::Int            = N_exc ÷ 4
    N_conn       ::Int            = N_inh + N_exc
    N            ::Int            = N_conn + N_unconn
    spike_rates  ::Distribution   = LogNormal_with_mean(4Hz, √0.6)  # (μₓ, σ)
end
const realistic_N_6600_input = PoissonInputParams()
const previous_N_30_input    = PoissonInputParams(N_unconn = 9, N_exc = 17)



@with_kw struct SynapseParams @deftype Float64

    avg_stim_rate_exc = 0.1 * nS / seconds  # Product of mean firing rate and postsynaptic
                                            # conductance increase per spike.
    avg_stim_rate_inh = 0.4 * nS / seconds

    E_exc          =     0   * mV   # Reversal potentials
    E_inh          =  - 65   * mV   #
    g_t0           =     0   * nS   # Conductances at `t = 0`
    τ              =     7   * ms   # Time constant of exponential decay of conductances
end
const realistic_synapses = SynapseParams()



@with_kw struct IzhikevichParams @deftype Float64
    C        =  100    * pF          # cell capacitance
    k        =    0.7  * (nS/mV)     # steepness of dv/dt's parabola
    v_rest   = - 60    * mV          # resting v
    v_thr    = - 40    * mV          # ~spiking thr
    a        =    0.03 / ms          # reciprocal of `u`'s time constant
    b        = -  2    * nS          # how strongly `(v - v_rest)` increases `u`
    v_peak   =   35    * mV          # cutoff to define spike
    v_reset  = - 50    * mV          # Reset after spike. `c` in Izh.
    Δu       =  100    * pA          # Increase on spike. `d` in Izh. Free parameter.
    v_t0     = v_rest
    u_t0     =    0    * pA
end
const cortical_RS = IzhikevichParams()



@with_kw struct VoltageImagingParams @deftype Float64
    spike_SNR      = 10
    spike_SNR_dB   = 20log10(spike_SNR)   # 1 ⇒ 0dB,  10 ⇒ 20dB,  100 ⇒ 40dB,  …
    spike_height
    σ_noise        = spike_height / spike_SNR
end

get_VI_params_for(izh::IzhikevichParams; kw...) =
    VoltageImagingParams(
        spike_height = izh.v_peak - izh.v_rest;
        kw...
    )



@with_kw struct SimParams
    duration       ::Float64                = 10 * seconds
    Δt             ::Float64                = 0.1 * ms
    num_timesteps  ::Int                    = round(Int, duration / Δt)
    rngseed        ::Int                    = 0  # For spike generation and imaging noise.
    input          ::PoissonInputParams     = realistic_N_6600_input
    synapses       ::SynapseParams          = realistic_synapses
    izh_neuron     ::IzhikevichParams       = cortical_RS
    imaging        ::VoltageImagingParams   = get_VI_params_for(izh_neuron)
end



@with_kw struct ConnTestParams
    STA_window_length  ::Float64   = 100 * ms
    num_shuffles       ::Int       = 100
    rngseed            ::Int       = 0           # For shuffling ISIs
end



@with_kw struct EvaluationParams
    α                             ::Float64  = 0.05   # p-value threshold / false detection rate
    num_tested_neurons_per_group  ::Int      = 40
    rngseed                       ::Int      = 0      # For selecting tested neurons
end



@with_kw struct ExperimentParams
    rngseed     ::Int                = 22022022
    sim         ::SimParams          = SimParams(; rngseed)
    conntest    ::ConnTestParams     = ConnTestParams(; rngseed)
    evaluation  ::EvaluationParams   = EvaluationParams(; rngseed)
end
const params = ExperimentParams()
