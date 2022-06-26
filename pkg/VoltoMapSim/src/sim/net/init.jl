
function init_sim(p::NetworkSimParams)

    @unpack duration, Δt, synapses, izh_neuron  = p.general
    @unpack N, EI_ratio, p_conn, N_to_record,
            g_EE, g_EI, g_IE, g_II, rngseed     = p.network
    @unpack g_t0, E_exc, E_inh                  = synapses
    @unpack v_t0, u_t0                          = izh_neuron

    num_timesteps = round(Int, duration / Δt)
    timesteps = linspace(zero(duration), duration, num_timesteps)  # for plotting

    # Convert {N, EI_ratio} to {N_exc, N_inh}
    p_exc = EI_ratio / (EI_ratio + 1)
    N_exc_neurons = round(Int, p_exc * N)
    N_inh_neurons = N - N_exc_neurons

    @assert N_exc_neurons ≥ N_to_record
    @assert N_inh_neurons ≥ N_to_record

    # Generate synaptic connections
    resetrng!(rngseed)
    is_connected = rand(N, N) .< p_conn   # [from, to]

    # Remove autapses
    for i = 1:N
        is_connected[i,i] = false
    end

    # Count synapses by type of pre- and postsynaptic neuron.
    M = N_exc_neurons
    N_synapses_per_type = (;
        exc_to_exc = count(is_connected[1:M, 1:M]),
        exc_to_inh = count(is_connected[1:M, M+1:end]),
        inh_to_exc = count(is_connected[M+1:end, 1:M]),
        inh_to_inh = count(is_connected[M+1:end, M+1:end]),
    )

    # IDs and subgroup names
    neuron_IDs  = idvec(exc = N_exc_neurons,  inh = N_inh_neurons)
    trace_IDs   = idvec(exc = N_to_record, inh = N_to_record)
    synapse_IDs = idvec(; N_synapses_per_type...)
    ODE_var_IDs = idvec(
        t     = scalar,
        v     = similar(neuron_IDs),   # membrane voltages
        u     = similar(neuron_IDs),   # adaptation currents
        g_exc = similar(neuron_IDs),   # [1]
        g_inh = similar(neuron_IDs),
    )
    # [1] Each element of `g_exc` is the sum of multiple synaptic conductances of one
    #     neuron, namely of all those synapses where the presynaptic neuron is excitatory.

    neuron_type = similar(neuron_IDs, Symbol)
    neuron_type.exc .= :exc
    neuron_type.inh .= :inh

    # Make synapse & neuron ID lookups.
    output_synapses = Dict{Int, Vector{Int}}()  # `neuron_ID => [synapse_IDs...]`
    postsyn_neuron  = Dict{Int, Int}()          # `synapse_ID => neuron_ID`
    for n in neuron_IDs  # init to empty
        output_synapses[n] = []
    end
    pre_post_pairs = Tuple.(findall(is_connected))  # Yields (row,col) i.e. neuron ID pairs
    for ((pre, post), synapse) in zip(pre_post_pairs, synapse_IDs)
        push!(output_synapses[pre], synapse)
        postsyn_neuron[synapse] = post
    end

    # Sample synaptic weights
    # (instantaneous increases in conductivity, Δg, on a presynaptic spike).
    syn_strengths = similar(synapse_IDs, Float64)  # Copy group names
    syn_strengths .= rand(p.network.syn_strengths, sum(N_synapses_per_type))
    # Make it so that: more inputs ⇔ less impact per input
    average_num_inputs = p_conn * N
    syn_strengths ./= average_num_inputs
    # Apply connection-type-specific multipliers
    syn_strengths.exc_to_exc .*= g_EE
    syn_strengths.exc_to_inh .*= g_EI
    syn_strengths.inh_to_exc .*= g_IE
    syn_strengths.inh_to_inh .*= g_II

    # Broadcast scalar parameter: spike transmission delays.
    spike_tx_delay = similar(synapse_IDs, Float64)
    spike_tx_delay .= p.network.tx_delay

    # Allocate memory to be overwritten every simulation step;
    # namely for the simulated variables and their time derivatives.
    vars = similar(ODE_var_IDs, Float64)
    vars.t = zero(duration)
    vars.v .= v_t0
    vars.u .= u_t0
    vars.g_exc .= g_t0
    vars.g_inh .= g_t0
    diff = similar(vars)  # = ∂x/∂t for every x in `vars`
    diff.t = 1 * s/s

    # Spike transmission queue. key = spike_ID, priority/val = spike_arrival_time.
    # a spike ID = (presyn neuron ID, synapse ID, spike arrival time)
    SpikeID = Tuple{Int, Int, Float64}
    upcoming_spike_arrivals = PriorityQueue{SpikeID, Float64}()

    # Where to record to.
    # We will record the spike times of all neurons ..
    spike_times = similar(neuron_IDs, Vector{Float64})  # vecs of timestamps
    for i in eachindex(neuron_IDs)
        spike_times[i] = []
    end
    # ..but the voltage traces of only a select number of neurons (to save space).
    voltage_traces = similar(trace_IDs, Vector{Float64})  # vecs of voltages
    for i in eachindex(trace_IDs)
        voltage_traces[i] = Vector{Float64}(undef, num_timesteps)
    end
    # Choose neurons to record from
    recorded_neurons = Dict{Int, Int}()  # trace_ID => neuron_ID
    recorded_exc_neurons = sample(neuron_IDs.exc, N_to_record, replace = false)
    for (m, n) in zip(trace_IDs.exc, recorded_exc_neurons)
        recorded_neurons[m] = n
    end
    recorded_inh_neurons = sample(neuron_IDs.inh, N_to_record, replace = false)
    for (m, n) in zip(trace_IDs.inh, recorded_inh_neurons)
        recorded_neurons[m] = n
    end

    # Create state object, as nested NamedTuple.
    return sim_state = (;
        init = (;
            num_timesteps,
            timesteps,
            neuron_IDs,
            trace_IDs,
            synapse_IDs,
            ODE_var_IDs,
            is_connected,
            neuron_type,
            recorded_neurons,
            output_synapses,
            postsyn_neuron,
            syn_strengths,
            spike_tx_delay,
        ),
        variable = (;
            upcoming_spike_arrivals,
            ODE = (;
                vars,
                diff,
            )
        ),
        rec = (;
            voltage_traces,
            spike_times,
        ),
    )
end
