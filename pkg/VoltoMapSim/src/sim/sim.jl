
include("net/init.jl")
include("net/step.jl")

include("Nto1/init.jl")  # See Nto1/ReadMe.md -- these need to be updated
include("Nto1/step.jl")

function sim(params::SimParams)
    state = init_sim(params)
    @showprogress (every = 400ms) "Running simulation: " (
    for i in 1:state.num_timesteps
        step_sim!(state, params, i)
    end)
    return state
end


# We don't add the VI noise in the main `sim` function, so that, for different noise levels,
# that function can be cached once and its output re-used.
function add_VI_noise(voltage_trace, p::ExperimentParams)
    @unpack v_peak, v_rest = p.sim.general.izh_neuron
    @unpack spike_SNR, rngseed = p.imaging
    spike_height = v_peak - v_rest
    σ_noise = spike_height / spike_SNR
    resetrng!(rngseed)
        # Note that we'll have same noise for every neuorn if applying this func to multiple.
    noise = randn(length(voltage_trace)) .* σ_noise
    return VI_sig = voltage_trace + noise
end



# The below functions are for a network sim state.

function augment_simdata(s, p::ExperimentParams)
    num_spikes_per_neuron = length.(s.spike_times)
    spike_rates           = num_spikes_per_neuron ./ p.sim.general.duration

    pre_post_pairs = Tuple.(findall(s.is_connected))
    synapse_ID_of_pair = Dict{Tuple{Int, Int}, Int}(zip(pre_post_pairs, s.synapse_IDs))

    s = (; s..., num_spikes_per_neuron, spike_rates, pre_post_pairs, synapse_ID_of_pair)

    @unpack record_v, record_all = p.sim.network
    recorded_neurons = unique(vcat(record_v, record_all))
    input_info = Dict([m => get_input_info(m, s, p) for m in recorded_neurons]...)

    return s = (; s..., input_info)
end

function get_input_info(m, s, p)
    # Return exc and inh inputs, sorted so the highest firing are first.
    # m = neuron ID
    # s = augmented simdata
    # p = ExperimentParams
    input_neurons = sort(s.input_neurons[m], by = n -> s.spike_rates[n], rev = true)
    exc_inputs = [n for n in input_neurons if s.neuron_type[n] == :exc]
    inh_inputs = [n for n in input_neurons if s.neuron_type[n] == :inh]
    unconnected_neurons = [n for n in s.neuron_IDs if n ∉ input_neurons && n != m]
    spiketrains = (
        conn = (
            exc = [s.spike_times[n] for n in exc_inputs],
            inh = [s.spike_times[n] for n in inh_inputs],
        ),
        unconn = [s.spike_times[n] for n in unconnected_neurons],
    )  # This datastructure is used by `evaluate_conntest_perf`
    return (;
        exc_inputs,
        inh_inputs,
        unconnected_neurons,
        spiketrains,
        v = s.signals[m].v,
        num_inputs = (exc = length(exc_inputs), inh = length(inh_inputs)),
    )
end
