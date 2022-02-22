function step_sim!(state, p::SimParams, init, rec, i)

    @unpack vars, D, upcoming_input_spikes                   = state
    @unpack t, v, u, g                                       = vars
    @unpack Δt, synapses, izh_neuron                         = p
    @unpack C, k, v_rest, v_thr, a, b, v_peak, v_reset, Δu   = izh_neuron
    @unpack ISI_distributions, postsynapses, Δg, E           = init

    # Sum synaptic currents
    I_s = zero(u)
    for (gi, Ei) in zip(g, E)
        I_s += gi * (v - Ei)
    end

    # Differential equations
    D.v = (k * (v - v_rest) * (v - v_thr) - u - I_s) / C
    D.u = a * (b * (v - v_rest) - u)
    for i in eachindex(g)
        D.g[i] = -g[i] / synapses.τ
    end

    # Euler integration
    @. vars += D * Δt

    # Izhikevich neuron spiking threshold
    if v ≥ v_peak
        vars.v = v_reset
        vars.u += Δu
    end

    # Record membrane voltage
    rec.v[i] = v

    # Input spikes
    next_input_spike_time = peek(upcoming_input_spikes).second  # (`.first` is neuron ID).
    if t ≥ next_input_spike_time
        n = dequeue!(upcoming_input_spikes)  # ID of the fired input neuron
        push!(rec.input_spikes[n], t)
        for s in postsynapses[n]
            g[s] += Δg[s]
        end
        tn = t + rand(ISI_distributions[n])  # Next spike time for the fired neuron
        enqueue!(upcoming_input_spikes, n => tn)
    end
    # Unhandled edge case: multiple spikes in the same time bin get processed with
    # increasing delay. (This problem goes away when using diffeq.jl, `adaptive`).
end
