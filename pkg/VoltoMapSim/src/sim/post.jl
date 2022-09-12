# Postprocessing and analysis functions, acting on SimData.


# We don't add the VI noise in the main `sim` function, so that, for different noise levels,
# that function can be cached once and its output re-used.
function add_VI_noise(voltage_trace, p::ExpParams)
    @unpack v_peak, v_rest = p.sim.general.izh_neuron
    @unpack spike_SNR, rngseed = p.imaging
    spike_height = v_peak - v_rest
    σ_noise = spike_height / spike_SNR
    resetrng!(rngseed)
        # Note that we'll have same noise for every neuron if applying this func to multiple.
    noise = randn(length(voltage_trace)) .* σ_noise
    return VI_sig = voltage_trace + noise
end


function augment(s::SimData, p::ExpParams)

    num_spikes_per_neuron = length.(s.spike_times)
    spike_rates           = num_spikes_per_neuron ./ p.sim.general.duration

    pre_post_pairs     = Tuple.(findall(s.is_connected))
    synapse_ID_of_pair = Dict(zip(pre_post_pairs, s.synapse_IDs))

    all = s.neuron_IDs
    type = s.neuron_type
    inputs = [sort(s.input_neurons[m], by = n -> spike_rates[n], rev = true) for m in all]
    exc_inputs = [[n for n in inputs[m] if type[n] == :exc] for m in all]
    inh_inputs = [[n for n in inputs[m] if type[n] == :inh] for m in all]
    non_inputs = [[n for n in all if n ∉ inputs[m] && n != m] for m in all]
    num_inputs = [(exc = length(exc_inputs[m]), inh = length(inh_inputs[m])) for m in all]

    return SimData(;
        s.data...,
        num_spikes_per_neuron,
        spike_rates,
        pre_post_pairs,
        synapse_ID_of_pair,
        exc_inputs,  # Exc inputs of a neuron, sorted by highest first.
        inh_inputs,
        non_inputs,
        num_inputs,
    )
end

function calc_avg_STA(s::SimData, p::ExpParams, postsyn_neurons, inputs)
    acc = nothing
    N = 0
    # @showprogress(
    for n in postsyn_neurons
        for m in inputs[n]
            STA = calc_STA(m => n, s, p)
            if isnothing(acc) acc = STA
            else acc .+= STA end
            N += 1
        end
    end
    # end)
    return avgSTA = acc ./ N
end

function calc_avg_STA_v2(s::SimData, p::ExpParams, postsyn_neurons, inputs)
    Δt::Float64 = p.sim.general.Δt
    win_size = round(Int, p.conntest.STA_window_length / Δt)
    acc = zeros(Float64, win_size)
    N = 0
    # @showprogress(
    for n in postsyn_neurons
        for m in inputs[n]
            STA = calc_STA(m => n, s, p)
            acc .+= STA
            N += 1
        end
    # end)
    end
    return avgSTA = acc ./ N
end
