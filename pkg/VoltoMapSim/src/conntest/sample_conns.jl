
function get_connections_to_test(s::SimData, p::ExpParams)
    # We do not test all N x N connections (that's too much).
    # The connections we do test are determined by which neurons
    # we record the voltage of, and the `N_tested_presyn` parameter.
    @unpack N_tested_presyn, rngseed = p.conntest
    connections_to_test = DataFrame(
        post     = Int[],     # neuron ID
        pre      = Int[],     # neuron ID
        conntype = Symbol[],  # :exc or :inh or :unconn
        posttype = Symbol[],  # :exc or :inh
    )
    resetrng!(rngseed)
    function get_labelled_sample(input_neurons, conntype)
        # Example output: `[(3, :exc), (5, :exc), (12, :exc), …]`.
        N = min(length(input_neurons), N_tested_presyn)
        inputs_sample = sample(input_neurons, N, replace = false, ordered = true)
        zip(inputs_sample, fill(conntype, N))
    end
    recorded_neurons = keys(s.v) |> collect |> sort!
    untested_conns = []
    for post in recorded_neurons
        posttype = s.neuron_type[post]
        inputs_to_test = chain(
            get_labelled_sample(s.exc_inputs[post], :exc),
            get_labelled_sample(s.inh_inputs[post], :inh),
            get_labelled_sample(s.non_inputs[post], :unconn),
        ) |> collect
        for (pre, conntype) in inputs_to_test
            if s.num_spikes_per_neuron[pre] > 0
                push!(connections_to_test, (; post, pre, conntype, posttype))
            else
                push!(untested_conns, pre)
            end
        end
    end
    if !isempty(untested_conns)
        n = length(untested_conns)
        @info "Left out $n connections because the presynaptic neuron did not spike."
    end
    return connections_to_test
end
