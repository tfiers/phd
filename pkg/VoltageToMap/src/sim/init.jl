function init_sim(p::SimParams)

    @unpack duration, Δt, num_timesteps, Δg_multiplier, seed   = p
    @unpack N_unconn, N_exc, N_inh, N_conn, N, spike_rate      = p.inputs
    @unpack g_t0, τ_s, E_exc, E_inh, Δg_exc, Δg_inh            = p.synapses
    @unpack v_t0, u_t0                                         = p.izh_neuron

    # IDs, subgroup names.
    input_neuron_IDs = idvec(conn = idvec(exc = N_exc, inh = N_inh), unconn = N_unconn)
    synapse_IDs      = idvec(exc = N_exc, inh = N_inh)
    var_IDs          = idvec(t = nothing, v = nothing, u = nothing, g = similar(synapse_IDs))

    resetrng!(seed)

    # Inter-spike—interval distributions
    λ = similar(input_neuron_IDs, Float64)
    λ .= rand(spike_rate, length(λ))
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
    Δg.exc .= Δg_multiplier * Δg_exc
    Δg.inh .= Δg_multiplier * Δg_inh
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
    v = Vector{Float64}(undef, num_timesteps)
    input_spikes = similar(input_neuron_IDs, Vector{Float64})
    for i in eachindex(input_spikes)
        input_spikes[i] = Vector{Float64}()
    end

    return (
        state = (; vars, D, upcoming_input_spikes),
        rec   = (; v, input_spikes),
        init  = (; ISI_distributions, postsynapses, Δg, E),
    )
end
