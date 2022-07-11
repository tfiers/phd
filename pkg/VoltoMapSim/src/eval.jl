
function sim_and_eval(params::ExperimentParams)
    simresult = cached(sim, [params.sim])
    @unpack vi, input_spikes = simresult
    perf = evaluate_conntest_perf(vi, input_spikes, params)
    return perf
end


function evaluate_conntest_perf(vi, input_spikes, p::ExperimentParams)
    @unpack rngseed, N_tested_presyn, α = p.evaluation
    resetrng!(rngseed)
    TP_exc = 0
    TP_inh = 0
    TP_unconn = 0
    get_N_eval(group) = min(length(group), N_tested_presyn)
    N_eval_exc    = get_N_eval(input_spikes.conn.exc)
    N_eval_inh    = get_N_eval(input_spikes.conn.inh)
    N_eval_unconn = get_N_eval(input_spikes.unconn)
    N_eval_total = N_eval_exc + N_eval_inh + N_eval_unconn
    # We could nicely rollup these three loops with Python's `yield`; alas not so easy here.

    get_subset_to_test(group) = group[1:get_N_eval(group)]  # should correspond to random sample
    p_values = (; conn = (; exc = [], inh = []), unconn = [])

    progress_meter = Progress(N_eval_total, 400ms, "Testing connections: ")
    for input_train in get_subset_to_test(input_spikes.conn.exc)
        p_value = test_connection(vi, input_train, p)
        push!(p_values.conn.exc, p_value)
        if p_value < α
            TP_exc += 1
        end
        next!(progress_meter)
    end
    for input_train in get_subset_to_test(input_spikes.conn.inh)
        p_value = test_connection(vi, input_train, p)
        push!(p_values.conn.inh, p_value)
        if p.conntest.STA_test_statistic == "ptp"
            # This is cheating: we presuppose we know whether the presyn neuron is inh.
            if p_value < α
                TP_inh += 1
            end
        else
            if p_value > 1 - α
                TP_inh += 1
            end
        end
        next!(progress_meter)
    end
    for input_train in get_subset_to_test(input_spikes.unconn)
        p_value = test_connection(vi, input_train, p)
        push!(p_values.unconn, p_value)
        if p.conntest.STA_test_statistic == "ptp"
            if p_value ≥ α
                TP_unconn += 1
            end
        else
            if α/2 ≤ p_value ≤ 1 - α/2
                TP_unconn += 1
            end
        end
        next!(progress_meter)
    end

    TPR_exc    = TP_exc / N_eval_exc
    TPR_inh    = TP_inh / N_eval_inh
    TPR_unconn = TP_unconn / N_eval_unconn
    FPR = 1 - TPR_unconn
    return (; p_values, detection_rates = (; TPR_exc, TPR_inh, FPR))
        # (; syntax for named tuple, using these var names)
end
