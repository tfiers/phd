
@kwdef struct PoissonInputsParams
    N_unconn     ::Int            = 100
    N_exc        ::Int            = 5200
    N_inh        ::Int            = N_exc ÷ 4
    N_conn       ::Int            = N_inh + N_exc
    N            ::Int            = N_conn + N_unconn
    spike_rates  ::Distribution   = LogNormal_with_mean(4Hz, √0.6)  # (μₓ, σ)
end
const realistic_N_6600_inputs = PoissonInputsParams()
const previous_N_30_inputs    = PoissonInputsParams(N_unconn = 9, N_exc = 17)


@kwdef struct SynapseParams
    Δg_exc         ::Float64   =     0.4 * nS   # Conductance increases on presynaptic spike
    Δg_inh         ::Float64   =     1.6 * nS   #
    Δg_multiplier  ::Float64   =     1          # Free param: fiddled with until Izh neuron spikes at ~2Hz.
    E_exc          ::Float64   =     0   * mV   # Reversal potentials
    E_inh          ::Float64   =  - 65   * mV   #
    g_t0           ::Float64   =     0   * nS   # Conductances at `t = 0`
    τ              ::Float64   =     7   * ms   # Time constant of exponential decay of conductances
end
const realistic_synapses = SynapseParams()


@kwdef struct IzhikevichParams
    C        ::Float64   =  100    * pF          # cell capacitance
    k        ::Float64   =    0.7  * (nS/mV)     # steepness of dv/dt's parabola
    v_rest   ::Float64   = - 60    * mV          # resting v
    v_thr    ::Float64   = - 40    * mV          # ~spiking thr
    a        ::Float64   =    0.03 / ms          # reciprocal of `u`'s time constant
    b        ::Float64   = -  2    * nS          # how strongly `(v - v_rest)` increases `u`
    v_peak   ::Float64   =   35    * mV          # cutoff to define spike
    v_reset  ::Float64   = - 50    * mV          # Reset after spike. `c` in Izh.
    Δu       ::Float64   =  100    * pA          # Increase on spike. `d` in Izh. Free parameter.
    v_t0     ::Float64   = v_rest
    u_t0     ::Float64   =    0    * pA
end
const cortical_RS = IzhikevichParams()

@kwdef struct VoltageImagingParams
    spike_SNR     ::Float64   = 10
    spike_SNR_dB  ::Float64   = 20log10(spike_SNR)   # 1⇒0dB, 10⇒20dB, 100⇒40dB, …
    spike_height  ::Float64
    σ_noise       ::Float64   = spike_height / spike_SNR
end
get_voltage_imaging_params(izh::IzhikevichParams, kw...) =
    VoltageImagingParams(spike_height = izh.v_peak - izh.v_rest; kw...)


@kwdef struct SimParams
    duration       ::Float64                = 10 * seconds
    Δt             ::Float64                = 0.1 * ms
    num_timesteps  ::Int                    = round(Int, duration / Δt)
    rngseed        ::Int                    = 0  # For spike generation and imaging noise.
    inputs         ::PoissonInputsParams    = realistic_N_6600_inputs
    synapses       ::SynapseParams          = realistic_synapses
    izh_neuron     ::IzhikevichParams       = cortical_RS
    imaging        ::VoltageImagingParams   = get_voltage_imaging_params(izh_neuron)
end


@kwdef struct ConnTestParams
    STA_window_length  ::Float64   = 100 * ms
    num_shuffles       ::Int       = 100
    rngseed            ::Int       = 0           # For shuffling ISIs
end


@kwdef struct EvaluationParams
    num_tested_neurons_per_group  ::Int   = 40
    rngseed                       ::Int   = 0    # For selecting tested neurons
end


@kwdef struct ExperimentParams
    rngseed     ::Int                = 22022022
    sim         ::SimParams          = SimParams(; rngseed)
    conntest    ::ConnTestParams     = ConnTestParams(; rngseed)
    evaluation  ::EvaluationParams   = EvaluationParams(; rngseed)
end
const params = ExperimentParams()
