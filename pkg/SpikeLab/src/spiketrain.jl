
"""
    SpikeTrain(spiketimes, duration; checksorted = true, makecopy = false)

Wrapper around a sorted list of spike times. Additionally, has a `duration` property. (The
spikes must occur within the time interval `[0, duration]`; i.e. no negative spike times).
"""
struct SpikeTrain
    spiketimes::Vector{Float64}
    duration::Float64

    SpikeTrain(spiketimes, duration; checksorted = true, makecopy = false) = begin
        s = makecopy ? copy(spiketimes) : spiketimes
        if checksorted && !issorted(s)
            sort!(s)
        end
        new(s, duration)
    end
end
Base.IndexStyle(::SpikeTrain) = IndexLinear
Base.getindex(t::SpikeTrain, i::Int) = t.spiketimes[i]
Base.size(t::SpikeTrain) = size(t.spiketimes)

spiketimes(t::SpikeTrain) = t.spiketimes
duration(t::SpikeTrain) = t.duration

spikerate(t::SpikeTrain) = length(t) / duration(t)

Base.merge(trains::AbstractVector{SpikeTrain}) =
    SpikeTrain(
        merge_sorted(spiketimes.(trains)),
        maximum(duration, trains);
        checksorted = false,
    )

merge_sorted(vecs) = sort!(reduce(vcat, vecs))
# This implementation does not explicitly make use of the fact that the vecs are already
# sorted. But quicksort performs well here. Much better than a specific implementation of
# `merge_sorted` I wrote (see this file and `test/merge_sorted.jl` in commit 15ec0d9).
