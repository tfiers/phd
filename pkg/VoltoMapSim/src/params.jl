"""
Parameters used in the simulation, connection tests, and performance evaluation; and their
default values.

`@deftype` is a macro from Parameters.jl that defines every field to have the specified type
(unless overridden) -- to avoid repetition.

On default argument values referencing previous arguments (e.g. in `IzhikevichParams`: `v_t0
 = v_rest`): This works when constructing a new object: `IzhParams(v_rest=…)` → `v_t0` gets
updated too. But not when using the `@set` macro (`@set cortical_RS.v_rest = -70 * mV` does
not change `v_t0`).
"""


abstract type ParamSet end
    # Used to identify parameter sets, to hash them by content (in `diskcache.jl`).


const default_rngseed = 22022022


@alias FlDistribution = ContinuousUnivariateDistribution
# `eltype(Distribution) == Any`, whereas for this it's `Float64`.


# Poisson spiking neurons, the input in the N-to-1 setup.
@with_kw struct Nto1InputParams <: ParamSet
    N_unconn      ::Int             = 100
    N_conn        ::Int             = 6500
    EI_ratio      ::Float64         = 4 / 1
    spike_rates   ::FlDistribution  = LogNormal_with_mean(4 * Hz, √0.6)  # (μₓ, σ)
    avg_stim_rate ::Float64         = 0.1 * nS / second                  # [1]
    rngseed       ::Int             = default_rngseed                    # for ISI generation
end
# [1] `avg_stim_rate` is used to calculate the postsynaptic conductance increase Δg per
#     spike for all excitatory neurons, by dividing by the mean of the `spike_rates`
#     distribution. Inhibitory neurons have an output stim rate `EI_ratio` higher than this.
#
const realistic_N_6600_input = Nto1InputParams()
    # Realistic N at least; spike rate dist is unknown.
const previous_N_30_input    = Nto1InputParams(N_unconn = 9, N_conn = 21)




@with_kw struct NetworkParams <: ParamSet
    N             ::Int           = 1000
    EI_ratio      ::Float64       = 4 / 1
    p_conn        ::Float64       = 0.10                              # [1]
    syn_strengths ::Distribution  = LogNormal_with_mean(20 * nS, 1)   # [2]
    g_EE          ::Float64       = 1                                 # [3]
    g_EI          ::Float64       = 1                                 # exc → inh
    g_IE          ::Float64       = EI_ratio
    g_II          ::Float64       = EI_ratio
    rngseed       ::Int           = default_rngseed                   # [4]
    tx_delay      ::Float64       = 10 * ms                           # spike transmission delay
    record_v      ::Vector{Int}   = [1]                               # neuron IDs
    record_all    ::Vector{Int}   = [1]                               # neuron IDs
end
# [1] p_conn:        probability that a random (pre, post)-neuron pair is connected.
# [2] syn_strengths: the increases in postsynaptic conductivity per incoming spike.
#                    This will be divided by the expected number of input neurons.
# [3] g_EI:          synaptic strength multiplier for excitatory → inhibitory neurons
# [4] rngseed:       for generating the connection matrix and synaptic strengths.




@with_kw struct SynapseParams <: ParamSet @deftype Float64
    E_exc    =    0   * mV           # Reversal potentials
    E_inh    = - 65   * mV           #
    g_t0     =    0   * nS           # Conductances at `t = 0`
    τ        =    7   * ms           # Time constant of exponential decay of conductances
end
const realistic_synapses = SynapseParams()

@with_kw struct IzhikevichParams <: ParamSet @deftype Float64
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




@with_kw struct VoltageImagingParams <: ParamSet
    spike_SNR     ::Float64  = 10               # [1]
    rngseed       ::Int      = default_rngseed  # For generating noise
end
# [1] spike_SNR_in_dB = 20log10(spike_SNR)   # 1 ⇒ 0dB,  10 ⇒ 20dB,  100 ⇒ 40dB,  …
#
const noisy_VI      = VoltageImagingParams()
const zero_noise_VI = VoltageImagingParams(spike_SNR = Inf)





@with_kw struct GeneralSimParams <: ParamSet
    duration        ::Float64                 = 10 * second
    Δt              ::Float64                 = 0.1 * ms
    izh_neuron      ::IzhikevichParams        = cortical_RS
    synapses        ::SynapseParams           = realistic_synapses
end

abstract type SimParams <: ParamSet end

@with_kw struct Nto1SimParams <: SimParams
    general ::GeneralSimParams = GeneralSimParams()
    input   ::Nto1InputParams  = realistic_N_6600_input
end

@with_kw struct NetworkSimParams <: SimParams
    general     ::GeneralSimParams  = GeneralSimParams()
    network     ::NetworkParams     = NetworkParams()
    ext_current ::FlDistribution    = Normal(0 * pA, 7 * pA)       # noise. [1]
    rngseed     ::Int               = default_rngseed              # for sampling noise
end
#
# [1]. Actual unit is pA/√s. See https://brian2.readthedocs.io/en/stable/user/models.html#noise
#      Also: by convention, current is positive for outward "+" flow.
#      So if this is negative, the voltage will increase.



@with_kw struct ConnTestParams <: ParamSet
    N_tested_presyn    ::Int       = 40                # Maximum, for each type of input (exc, inh, non-input).
    num_shuffles       ::Int       = 100
    STA_window_length  ::Float64   = 100 * ms
    rngseed            ::Int       = default_rngseed   # For selecting tested inputs, and shuffling ISIs.
end



@with_kw struct ExperimentParams <: ParamSet
    sim         ::SimParams
    imaging     ::VoltageImagingParams  = noisy_VI
    conntest    ::ConnTestParams        = ConnTestParams()
end



# Utility function to tersely construct a parameter tree
function get_params(T = ExperimentParams; kw...)
    # For every field of the T,
    # - if it's a ParamSet, recurse
    # - if it's in kw, use the value in kw
    # - else, use the default (i.e. do not supply it)
    kw = Dict(kw)
    kw_for_T = Dict{Symbol, Any}()
    for (name, type) in zip(fieldnames(T), fieldtypes(T))
        if type <: ParamSet
            if type <: SimParams
                type = NetworkSimParams
            end
            kw_for_T[name] = get_params(type; kw...)
        elseif name in keys(kw)
            kw_for_T[name] = kw[name]
        end
    end
    return T(; kw_for_T...)
end
