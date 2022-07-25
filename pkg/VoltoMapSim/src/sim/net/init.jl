
function init_sim(p::NetworkSimParams)

    @unpack duration, Δt, synapses, izh_neuron  = p.general
    @unpack N, EI_ratio, p_conn, rngseed,
            g_EE, g_EI, g_IE, g_II,
            record_v, record_all                = p.network
    @unpack g_t0, E_exc, E_inh                  = synapses
    @unpack v_t0, u_t0                          = izh_neuron

    num_timesteps = round(Int, duration / Δt)
    timesteps = linspace(zero(duration), duration, num_timesteps)  # for plotting

    # Convert {N, EI_ratio} to {N_exc, N_inh}
    p_exc = EI_ratio / (EI_ratio + 1)
    N_exc_neurons = round(Int, p_exc * N)
    N_inh_neurons = N - N_exc_neurons

    # Generate synaptic connections
    resetrng!(rngseed)
    is_connected = rand(N, N) .< p_conn   # [from, to]

    # Remove autapses
    for i = 1:N
        is_connected[i,i] = false
    end

    N_synapses = count(is_connected)

    # IDs and subgroup names
    neuron_IDs  = idvec(exc = N_exc_neurons,  inh = N_inh_neurons)
    synapse_IDs = collect(1:N_synapses)
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
    input_synapses  = Dict{Int, Vector{Int}}()  # `neuron_ID => [synapse_IDs...]`
    postsyn_neuron  = Dict{Int, Int}()          # `synapse_ID => neuron_ID`
    presyn_neuron   = Dict{Int, Int}()          # `synapse_ID => neuron_ID`
    input_neurons   = Dict{Int, Vector{Int}}()  # `neuron_ID => [neuron_IDs...]`
    output_neurons  = Dict{Int, Vector{Int}}()  # `neuron_ID => [neuron_IDs...]`
    syns = synapse_IDs_by_group = (;
        exc_to_exc = [],
        exc_to_inh = [],
        inh_to_exc = [],
        inh_to_inh = [],
    )
    for n in neuron_IDs  # init to empty
        output_synapses[n] = []
        input_synapses[n] = []
        output_neurons[n] = []
        input_neurons[n] = []
    end

    pre_post_pairs = Tuple.(findall(is_connected))
        # Yields (row,col) i.e. neuron ID pairs. Traversed column-major (r1c1, r2c1, …).

    for ((pre, post), synapse) in zip(pre_post_pairs, synapse_IDs)
        push!(output_synapses[pre], synapse)
        push!(input_synapses[post], synapse)
        push!(input_neurons[post], pre)
        push!(output_neurons[pre], post)
        postsyn_neuron[synapse] = post
        presyn_neuron[synapse] = pre
        syngroup = @match (neuron_type[pre], neuron_type[post]) begin
            (:exc, :exc) => syns.exc_to_exc
            (:exc, :inh) => syns.exc_to_inh
            (:inh, :exc) => syns.inh_to_exc
            (:inh, :inh) => syns.inh_to_inh
        end
        push!(syngroup, synapse)
    end

    # Sample synaptic weights
    # (instantaneous increases in conductivity, Δg, on a presynaptic spike).
    syn_strengths = similar(synapse_IDs, Float64)
    syn_strengths .= rand(p.network.syn_strengths, N_synapses)
    # Make it so that: more inputs ⇔ less impact per input
    average_num_inputs = p_conn * N
    syn_strengths ./= average_num_inputs
    # Apply connection-type-specific multipliers
    syn_strengths[syns.exc_to_exc] .*= g_EE
    syn_strengths[syns.exc_to_inh] .*= g_EI
    syn_strengths[syns.inh_to_exc] .*= g_IE
    syn_strengths[syns.inh_to_inh] .*= g_II

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
    diff.t = 1 * seconds/seconds

    # Spike transmission queue. key = spike_ID. priority/val = spike_arrival_time.
    # a spike ID = (presyn neuron ID, synapse ID, spike time)
    SpikeID = Tuple{Int, Int, Float64}
    upcoming_spike_arrivals = PriorityQueue{SpikeID, Float64}()

    # Where to record to.
    # We will record the spike times of all neurons ..
    spike_times = similar(neuron_IDs, Vector{Float64})  # vecs of timestamps
    for i in eachindex(neuron_IDs)
        spike_times[i] = []
    end
    # ..but the voltage traces of only a select number of neurons (to save space).
    signals = Dict{Int, Any}()
    for n in record_v
        signals[n] = (
            v = Vector{Float64}(undef, num_timesteps),
        )
    end
    for n in record_all
        signals[n] = (
            v     = Vector{Float64}(undef, num_timesteps),
            u     = Vector{Float64}(undef, num_timesteps),
            g_exc = Vector{Float64}(undef, num_timesteps),
            g_inh = Vector{Float64}(undef, num_timesteps),
        )
    end

    # Create state object, as nested NamedTuple.
    return state = (;
        #
        # Fixed at init:
        num_timesteps,
        timesteps,
        neuron_IDs,
        synapse_IDs,
        ODE_var_IDs,
        is_connected,
        neuron_type,
        output_synapses,
        input_synapses,
        postsyn_neuron,
        presyn_neuron,
        input_neurons,
        output_neurons,
        syns,
        syn_strengths,
        spike_tx_delay,
        #
        # Variable each timestep:
        upcoming_spike_arrivals,
        ODE = (;
            vars,
            diff,
        ),
        #
        # Recording containers:
        spike_times,
        signals,
    )
end
