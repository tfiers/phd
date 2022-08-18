
"""
`μ` and `σ` are mean and standard deviation of the underlying Gaussian.
`μₓ` is the mean of the log of the Gaussian.
"""
function LogNormal_with_mean(μₓ, σ)
    μ = log(μₓ) - σ^2 / 2
    return LogNormal(μ, σ)
end

"""'peak-to-peak'"""
ptp(signal) = maximum(signal) - minimum(signal)


function bin(spiketimes; duration, binsize)
    # `spiketimes` is assumed sorted.
    # `duration` is of the spiketimes signal and co-determines the number of bins.
    num_bins = ceil(Int, duration / binsize)
    spikecounts = fill(0, num_bins)
    # loop counters:
    spike = 1
    bin_end_time = binsize
    for bin in 1:num_bins
        while spiketimes[spike] < bin_end_time
            spikecounts[bin] += 1
            spike += 1
            if spike > length(spiketimes)
                return spikecounts
            end
        end
        bin_end_time += binsize
    end
end;
