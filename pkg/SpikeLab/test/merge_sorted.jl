using SpikeLab: merge_sorted, poisson_spikes
using SpikeLab.Units

# Alternative implementation of `merge_sorted`
quicksort_merge(vecs) = sort!(reduce(vcat, vecs))

vecs = [poisson_spikes(10Hz, 10minutes) for _ in 1:10]
vecs_simple = [
    [0, 1, 2],
    [1, 3, 8],
]
# vecs = vecs_simple

merged = merge_sorted(vecs)

@assert issorted(merged)
@assert length(merged) == sum(length, vecs)
@assert merged == quicksort_merge(vecs)


# julia> vecs = [poisson_spikes(10Hz, 10minutes) for _ in 1:100];

# julia> @time merge_sorted(vecs);
#   0.768417 seconds (1.20 M allocations: 22.961 MiB, 1.95% gc time)

# julia> @time quicksort_merge(vecs);
#   0.033903 seconds (3 allocations: 4.583 MiB)
#
# 😂
