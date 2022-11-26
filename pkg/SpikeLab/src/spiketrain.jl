
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


"""
    merge_sorted(vecs)

Given a list of sorted vectors, return a single sorted vector of all elements.

Not to be confused with mergesort. (Although this function _does_ do the same thing as the
`merge` part in mergesort -- only for an arbitrary number of arrays, instead of two).
"""
function merge_sorted(vecs)
    T = typejoin(eltype.(vecs)...)
    N = sum(length, vecs)
    merged = Vector{T}(undef, N)
    vecs = [v for v in vecs if length(v) > 0]
    curval = @inbounds [v[1] for v in vecs]
    curptr = [1 for v in vecs]
    active = BitSet(1:length(vecs))  # Vecs that are not exhausted yet
    @inbounds for i in 1:N
        # Find the smallest of the active vecs' current values
        # (We cannot use `findmin(curval[j] for j in active)`, as there's no `keys(::BitSet)`).
        smallest = nothing
        ĵ = nothing
        for j in active
            val = curval[j]
            if isnothing(smallest) || val < smallest
                smallest = val
                ĵ = j
            end
        end
        # ..and add it to the output list
        merged[i] = smallest
        # Advance the current-element pointer of vec ĵ
        k = (curptr[ĵ] += 1)
        vec = vecs[ĵ]
        if k > length(vec)      # Check if exhausted
            delete!(active, ĵ)  # If so, remove from active set
        else
            curval[ĵ] = vec[k]  # Otherwise, update the current value
        end
    end
    return merged
end
#
# There is https://github.com/vvjn/MergeSorted.jl
# but that is only for two vectors, not an arbitrary number.
# (What is perf of applying this recursively?)
#
# Also, `sort!(reduce(vcat, vecs))` might be efficient enough:
# "QuickSort usually performs well on pre-sorted arrays"
# (https://stackoverflow.com/a/35841650/2611913)
