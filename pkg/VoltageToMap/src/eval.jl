
function performance_for(p::ExperimentParams)
    t, v, vi, input_spikes, state = sim(p.sim);
    return evaluate_conntest_performance(vi, input_spikes, p)
end


function evaluate_conntest_performance(vi, input_spikes, p::ExperimentParams)
    @unpack rngseed, num_tested_neurons_per_group, α = p.evaluation
    resetrng!(rngseed)
    TP_exc = 0
    TP_inh = 0
    TP_unconn = 0
    get_N_eval(group) = min(length(group), num_tested_neurons_per_group)
    get_subset_to_test(group) = group[1:get_N_eval(group)]  # should correspond to random sample

    for input_train in get_subset_to_test(input_spikes.conn.exc)
        p_value = test_connection(vi, input_train, p)
        if p_value < α
            TP_exc += 1
        end
    end
    for input_train in get_subset_to_test(input_spikes.conn.inh)
        p_value = test_connection(vi, input_train, p)
        if p_value > 1 - α
            TP_inh += 1
        end
    end
    for input_train in get_subset_to_test(input_spikes.unconn)
        p_value = test_connection(vi, input_train, p)
        if α/2 ≤ p_value ≤ 1 - α/2
            TP_unconn += 1
        end
    end

    TPR_exc    = TP_exc / get_N_eval(input_spikes.conn.exc)
    TPR_inh    = TP_inh / get_N_eval(input_spikes.conn.inh)
    TPR_unconn = TP_unconn / get_N_eval(input_spikes.unconn)
    FPR = 1 - TPR_unconn
    return (; TPR_exc, TPR_inh, FPR)  # (syntax for named tuple, using these var names)
end
