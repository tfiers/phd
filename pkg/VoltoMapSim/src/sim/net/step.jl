
function step_sim!(state, params::NetworkSimParams, i)

    @unpack input_synapses, output_synapses, recorded_neurons,
            syn_reversal_pot, syn_strengths, spike_prop_delay    = state.init
    @unpack ODE, upcoming_spike_arrivals                         = state.variable
    @unpack spike_times, voltage_traces                          = state.rec
    @unpack v, u, g                                              = ODE.vars
    @unpack ext_current, rngseed                                 = params
    @unpack Δt, izh_neuron, synapses                             = params.general
    @unpack C, k, v_rest, v_thr, a, b, v_peak, v_reset, Δu       = izh_neuron

    # Sum synaptic input currents for each neuron
    I_s = zero(u)
    E = syn_reversal_pot
    for n in eachindex(I_s)         # n = neuron ID
        for s in input_synapses[n]  # s = synapse ID
            I_s[n] += g[s] * (v[n] - E[s])  # Convention: positive if outward '+' flow.
        end
    end

    # Sample external current
    I_ext = rand(ext_current, length(u)) ./ √Δt
        # On √Δt: See https://brian2.readthedocs.io/en/stable/user/models.html#noise

    # Differential equations.
    # Izhikevich dynamics for voltage & adaptation current
    @. ODE.diff.v = (k *  (v - v_rest) * (v - v_thr) - u - I_s - I_ext) / C
    @. ODE.diff.u = a * (b * (v - v_rest) - u)
    # Synaptic conductance decay
    @. ODE.diff.g = - g / synapses.τ

    # Euler integration
    @. ODE.vars += ODE.diff * Δt

    t = ODE.vars.t

    # Spiking threshold
    has_spiked = v .≥ v_peak
    for n in findall(Vector(has_spiked))  # `findall` directly on Bit CVec errors.
        # Izhikevich discontinuity
        ODE.vars.v[n] = v_reset
        ODE.vars.u[n] += Δu
        # Record spike time
        push!(spike_times[n], t)
        # Propagate spike to output synapses
        for s in output_synapses[n]
            spike_ID = (n, s, t)
            spike_arrival_time = t + spike_prop_delay[s]
            enqueue!(upcoming_spike_arrivals, spike_ID => spike_arrival_time)
        end
    end

    # Record membrane voltage of selected neurons
    for t in eachindex(voltage_traces)
        n = recorded_neurons[t]
        voltage_traces[t][i] = v[n]
    end

    # Process spikes arriving at synapses
    function there_are_spikes_left_to_process()
        if isempty(upcoming_spike_arrivals)
            return false
        else
            t_next_arrival = peek(upcoming_spike_arrivals).second  # (`.first` is spike ID)
            return t_next_arrival ≤ t
        end
    end
    while there_are_spikes_left_to_process()
        (_, s, _) = dequeue!(upcoming_spike_arrivals)  # s = synapse ID.
        g[s] += syn_strengths[s]
    end
end
