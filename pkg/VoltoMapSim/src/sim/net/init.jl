
function init_sim(p::NetworkSimParams)

    @unpack duration, Δt, synapses, izh_neuron         = p.general
    @unpack N, EI_ratio, p_conn, rngseed, N_to_record  = p.network
    @unpack g_t0, E_exc, E_inh                         = synapses
    @unpack v_t0, u_t0                                 = izh_neuron

    num_timesteps = round(Int, duration / Δt)
    timesteps = linspace(zero(duration), duration, num_timesteps)  # for plotting

    # Convert {N, EI ratio} to {N_exc, N_inh}
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

    # Count synapses by type of presynaptic neuron
    N_exc_synapses = count(is_connected[1:N_exc_neurons, :])
    N_inh_synapses = count(is_connected[N_exc_neurons+1:end, :])

    # IDs and subgroup names
    neuron_IDs  = idvec(exc = N_exc_neurons,  inh = N_inh_neurons)
    trace_IDs   = idvec(exc = N_to_record,    inh = N_to_record)
    synapse_IDs = idvec(exc = N_exc_synapses, inh = N_inh_synapses)
    ODE_var_IDs = idvec(
        t = scalar,
        v = similar(neuron_IDs),   # membrane voltages
        u = similar(neuron_IDs),   # adaptation currents
        g = similar(synapse_IDs),  # synaptic conductances
    )

    # Make synapse ID lookups. Both are in the form `neuron_ID => [synapse_IDs...]`)
    output_synapses = Dict{Int, Vector{Int}}()
    input_synapses  = Dict{Int, Vector{Int}}()
    for n in neuron_IDs  # init to empty
        output_synapses[n] = []
        input_synapses[n]  = []
    end
    pre_post_pairs = Tuple.(findall(is_connected))  # Yields (row,col) i.e. neuron ID pairs
    for ((pre, post), synapse) in zip(pre_post_pairs, synapse_IDs)
        push!(output_synapses[pre], synapse)
        push!(input_synapses[post], synapse)
    end

    # Sample synaptic weights
    # (instantaneous increases in conductivity, Δg, on a presynaptic spike).
    syn_strengths = similar(synapse_IDs, Float64)  # Copy group names
    exc_distr = p.network.syn_strengths
    inh_distr = EI_ratio * exc_distr
    syn_strengths.exc .= rand(exc_distr, N_exc_synapses)
    syn_strengths.inh .= rand(inh_distr, N_inh_synapses)

    # Broadcast scalar parameters: synaptic reversal potentials and spike transmission delays.
    syn_reversal_pot = similar(synapse_IDs, Float64)
    syn_reversal_pot.exc .= E_exc
    syn_reversal_pot.inh .= E_inh
    spike_prop_delay = similar(synapse_IDs, Float64)
    spike_prop_delay .= p.network.tx_delay

    # Allocate memory to be overwritten every simulation step;
    # namely for the simulated variables and their time derivatives.
    vars = similar(ODE_var_IDs, Float64)
    vars.t = zero(duration)
    vars.v .= v_t0
    vars.u .= u_t0
    vars.g .= g_t0
    diff = similar(vars)  # = ∂x/∂t for every x in `vars`
    diff.t = 1 * s/s

    # Spike transmission queue. key = spike_ID, priority = spike_arrival_time.
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
    for (t, n) in zip(trace_IDs.exc, recorded_exc_neurons)
        recorded_neurons[t] = n
    end
    recorded_inh_neurons = sample(neuron_IDs.inh, N_to_record, replace = false)
    for (t, n) in zip(trace_IDs.inh, recorded_inh_neurons)
        recorded_neurons[t] = n
    end

    # Create state object, as nested NamedTuple.
    return sim_state = (;
        init = (;
            num_timesteps,
            timesteps,  # (we could also rec vars.t instead)
            neuron_IDs,
            trace_IDs,
            synapse_IDs,
            ODE_var_IDs,
            is_connected,
            recorded_neurons,
            output_synapses,
            input_synapses,
            syn_strengths,
            syn_reversal_pot,
            spike_prop_delay,
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
