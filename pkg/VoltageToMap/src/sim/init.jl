function init_sim(p::SimParams)

    @unpack duration, num_timesteps, seed, inputs, synapses, izh_neuron   = p
    @unpack N_unconn, N_exc, N_inh, N_conn, N                             = inputs
    @unpack g_t0, E_exc, E_inh, Δg_exc, Δg_inh, Δg_multiplier             = synapses
    @unpack v_t0, u_t0                                                    = izh_neuron

    # IDs, subgroup names.
    input_neuron_IDs = IDVec(:conn = (:exc = N_exc, :inh = N_inh), :unconn = N_unconn)
    synapse_IDs      = IDVec(:exc = N_exc, :inh = N_inh)
    var_IDs          = IDVec(:t, :v, :u, :g = similar(synapse_IDs))

    resetrng!(seed)

    # Inter-spike—interval distributions
    λ = similar(input_neuron_IDs, Float64)
    λ .= rand(inputs.spike_rates, length(λ))
    β = 1 ./ λ
    ISI_distributions = Exponential.(β)

    # Input spikes queue
    first_input_spike_times = rand.(ISI_distributions)
    upcoming_input_spikes   = PriorityQueue{Int, Float64}()
    for (n, t) in zip(input_neuron_IDs, first_input_spike_times)
        enqueue!(upcoming_input_spikes, n => t)
    end

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
    Δg.exc .= Δg_exc * Δg_multiplier
    Δg.inh .= Δg_inh * Δg_multiplier
    E = similar(synapse_IDs, Float64)
    E.exc .= E_exc
    E.inh .= E_inh

    # Allocate memory to be repeatedly overwritten
    vars = similar(var_IDs, Float64)
    vars.t = zero(duration)
    vars.v = v_t0
    vars.u = u_t0
    vars.g .= g_t0
    D = similar(vars)
    D.t = 1

    # Where to record to
    v_rec = Vector{Float64}(undef, num_timesteps)
    input_spikes = similar(input_neuron_IDs, Vector{Float64})
    for i in eachindex(input_spikes)
        input_spikes[i] = Vector{Float64}()
    end

    return (
        state = (; vars, D, upcoming_input_spikes),
        init  = (; ISI_distributions, postsynapses, Δg, E),
        rec   = (; v = v_rec, input_spikes),
    )
end
