
function test_connection_and_type(v, spikes, p::ExperimentParams)
    pval = test_connection(v, spikes, p)
    dt = p.sim.general.Δt
    A = area(calc_STA(v, spikes, p)) * dt / (mV*ms)
    if pval ≥ p.evaluation.α
        predicted_type = :unconn
    elseif A > 0
        predicted_type = :exc
    else
        predicted_type = :inh
    end
    return (; predicted_type, pval, area_over_start=A)
end

cached_conntest_eval(s, m, p; verbose = true) =
    cached(evaluate_conntest_perf, [s, m, p, verbose]; key = [m, p], verbose);

function evaluate_conntest_perf(s, m, p::ExperimentParams, verbose = true)
    # s = augmented simdata
    # m = postsynaptic neuron ID
    @unpack N_tested_presyn, rngseed = p.evaluation;
    resetrng!(rngseed)
    function get_IDs_labels(IDs, label)
        N = min(length(IDs), N_tested_presyn)
        IDs_sample = sample(IDs, N, replace = false, ordered = true)
        return zip(IDs_sample, fill(label, N))
    end
    ii = s.input_info[m]
    IDs_labels = chain(
        get_IDs_labels(ii.exc_inputs, :exc),
        get_IDs_labels(ii.inh_inputs, :inh),
        get_IDs_labels(ii.unconnected_neurons, :unconn),
    ) |> collect
    tested_neurons = DataFrame(
        input_neuron_ID = Int[],     # global ID
        real_type       = Symbol[],  # :unconn, :exc, :inh
        predicted_type  = Symbol[],  # idem
        pval            = Float64[],
        area_over_start = Float64[],
    )
    N = length(IDs_labels)
    pbar = Progress(N, desc = "Testing connections: ", enabled = verbose, dt = 400ms)
    for (n, label) in collect(IDs_labels)
        test_result = test_connection_and_type(ii.v, s.spike_times[n], p)
        row = (input_neuron_ID = n, real_type = label, test_result...)
        push!(tested_neurons, Dict(pairs(row)))
        next!(pbar)
    end

    tn = tested_neurons
    det_rate(t) = count((tn.real_type .== t) .& (tn.predicted_type .== t)) / count(tn.real_type .== t)
    detection_rates = (
        TPR_exc = det_rate(:exc),
        TPR_inh = det_rate(:inh),
        FPR = 1 - det_rate(:unconn),
    )
    return (; tested_neurons, detection_rates)
end
