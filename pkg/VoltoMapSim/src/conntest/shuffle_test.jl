
shuffle_ISIs(spiketimes) = to_spiketimes!(shuffle!(to_ISIs(spiketimes)))

to_ISIs(spiketimes) = [first(spiketimes); diff(spiketimes)]  # copying
to_spiketimes!(ISIs) = cumsum!(ISIs, ISIs)                   # in place

function calc_pval(test_stat, real_STA, shuffled_STAs)
    # `shuffled_STAs` are STAs where the real presynaptic spikes have been ISI-shuffled.
    N = length(shuffled_STAs)
    real_t = test_stat(real_STA)
    H0_ts  = test_stat.(shuffled_STAs)      # What we'd see if unconnected.
    num_H0_larger = count(H0_ts .≥ real_t)  # [1]
    if num_H0_larger == 0
        pval = 1 / N
        type = "<"
    else
        pval = num_H0_larger / N
        type = "="
    end
    return (; pval, type)
end
# [1] Greater _or equal_, as p-value is probability of observing t values *at least as*
#     extreme as the real t:   p-value = P(T ≥ t | H0)
