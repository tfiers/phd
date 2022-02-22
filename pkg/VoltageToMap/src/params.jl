@kwdef struct PoissonInputParams
    N_unconn  ::Int          = 100
    N_exc     ::Int          = 5200
    N_inh     ::Int          = N_exc ÷ 4
    N_conn    ::Int          = N_inh + N_exc
    N         ::Int          = N_conn + N_unconn
    spike_rate::Distribution = LogNormal_with_mean(4Hz, √0.6)  # (μₓ, σ)
end
const realistic_input = PoissonInputParams()
const small_N__as_in_Python_2021 = PoissonInputParams(N_unconn = 9, N_exc = 17)  # N == 30

@kwdef struct SynapseParams
    g_t0     ::Float64   =     0   * nS
    τ_s      ::Float64   =     7   * ms
    E_exc    ::Float64   =     0   * mV
    E_inh    ::Float64   =  - 65   * mV
    Δg_exc   ::Float64   =     0.4 * nS
    Δg_inh   ::Float64   =     1.6 * nS
end
const semi_arbitrary_synaptic_params = SynapseParams()

@kwdef struct IzhNeuronParams
    C        ::Float64   =  100    * pF
    k        ::Float64   =    0.7  * (nS/mV)     # steepness of dv/dt's parabola
    vr       ::Float64   = - 60    * mV          # resting v
    vt       ::Float64   = - 40    * mV          # ~spiking thr
    a        ::Float64   =    0.03 / ms          # reciprocal of `u`'s time constant
    b        ::Float64   = -  2    * nS          # how strongly `(v - vr)` increases `u`
    v_peak   ::Float64   =   35    * mV          # cutoff to define spike
    v_reset  ::Float64   = - 50    * mV          # ..on spike. `c` in Izh.
    Δu       ::Float64   =  100    * pA          # ..on spike. `d` in Izh. Free parameter.
    v_t0     ::Float64   =    vr
    u_t0     ::Float64   =    0    * pA
end
const cortical_RS = IzhNeuronParams()

@kwdef struct SimParams
    duration      ::Float64            = 1.2 * seconds
    Δt            ::Float64            = 0.1 * ms
    num_timesteps ::Int                = round(Int, duration / Δt)
    poisson_input ::PoissonInputParams = realistic_input
    synapses      ::SynapseParams      = semi_arbitrary_synaptic_params
    izh_neuron    ::IzhNeuronParams    = cortical_RS
    Δg_multiplier ::Float64            = 1.0      # Free parameter, fiddled with until medium number of output spikes.
    seed          ::Int                = 2022
end
