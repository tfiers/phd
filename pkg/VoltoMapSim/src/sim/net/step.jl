
function step_sim!(state, params::NetworkSimParams, i)

    @unpack output_synapses, postsyn_neuron, neuron_type,
            syn_strengths, spike_tx_delay                        = state
    @unpack ODE, upcoming_spike_arrivals                         = state
    @unpack spike_times, signals                                 = state
    @unpack v, u, g_exc, g_inh                                   = ODE.vars
    @unpack ext_current, rngseed                                 = params
    @unpack Δt, synapses, izh_neuron                             = params.general
    @unpack record_v, record_all                                 = params.network
    @unpack τ, E_exc, E_inh                                      = synapses
    @unpack C, k, v_rest, v_thr, a, b, v_peak, v_reset, Δu       = izh_neuron

    # Calculate synaptic input current for each neuron
    I = similar(u)
    for n in eachindex(I)  # n = neuron ID
        I[n] = (  g_exc[n] * (v[n] - E_exc)
                + g_inh[n] * (v[n] - E_inh))
    end  # Convention: current positive if outward '+' flow.

    # Sample external current
    I_ext = rand(ext_current, length(u))::Vector{Float64} ./ √Δt
        # On √Δt: See https://brian2.readthedocs.io/en/stable/user/models.html#noise

    # Differential equations.
    # Izhikevich dynamics for voltage & adaptation current:
    @. ODE.diff.v = (k *  (v - v_rest) * (v - v_thr) - u - I - I_ext) / C
    @. ODE.diff.u = a * (b * (v - v_rest) - u)
    # Synaptic conductance decay:
    @. ODE.diff.g_exc = - g_exc / τ
    @. ODE.diff.g_inh = - g_inh / τ

    # Euler integration
    @. ODE.vars += ODE.diff * Δt

    @unpack t, v, u, g_exc, g_inh = ODE.vars

    # Spiking threshold
    has_spiked = v .≥ v_peak
    for n in findall(Vector(has_spiked))  # `findall` directly on Bit CVec errors.
        # Izhikevich discontinuity
        v[n] = v_reset
        u[n] += Δu
        # Record spike time
        push!(spike_times[n], t)
        # Propagate spike to output synapses
        for s in output_synapses[n]
            spike_ID = (n, s, t)
            spike_arrival_time = t + spike_tx_delay[s]
            enqueue!(upcoming_spike_arrivals, spike_ID => spike_arrival_time)
        end
    end

    # Record ODE vars of selected neurons.
    for n in record_v
        signals[n].v[i]     = v[n]
    end
    for n in record_all
        signals[n].v[i]     = v[n]
        signals[n].u[i]     = u[n]
        signals[n].g_exc[i] = g_exc[n]
        signals[n].g_inh[i] = g_inh[n]
    end

    # Process spikes arriving at synapses: Keep removing spikes from the queue until there
    # are none left, or only ones that have a future arrival time.
    while !isempty(upcoming_spike_arrivals) && peekval(upcoming_spike_arrivals) ≤ t
        (n, s, _) = dequeue!(upcoming_spike_arrivals)  # n = neuron ID, s = synapse ID
        presyn_neuron_type = neuron_type[n]
        p = postsyn_neuron[s]
        if presyn_neuron_type == :exc
            g_exc[p] += syn_strengths[s]
        else
            g_inh[p] += syn_strengths[s]
        end
    end
end

"""Return the value ('priority') of the first (highest priority) item in the queue."""
peekval(pq::PriorityQueue) = peek(pq).second
