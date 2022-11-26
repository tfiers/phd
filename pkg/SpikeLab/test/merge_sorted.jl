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
