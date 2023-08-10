
using Random: randexp

"""
    poisson_spikes(r, T)

Generate Poisson spiketimes with mean firing rate `r` on the time interval `[0, T]`.

More precisely, simulate a Poisson process by drawing inter-spike-intervals from an
Exponential distribution with rate parameter `r`, accumulating them until `T` is reached.
The number of spikes `N` in `[0, T]` will be Poisson-distributed, with mean = `rT`.

The output is a length-`N` (i.e. variable-length) vector of spike times.
"""
function poisson_spikes(r, T)
    # As we cannot predict how many spikes we will have generated when reaching `T`, we
    # allocate an array long enough to very likely fit all of them, and trim off the unused
    # end on return.¹
    max_N = round(Int, 300 + 1.05 * r * T)
    # ↪ That linear formula is an approximate upper bound on `cquantile(Poisson(r*T), 1E-14)`
    spikes = Vector{Float64}(undef, max_N)
    N = 0
    rand_ISI() = randexp() / r
    t = rand_ISI()
    while t ≤ T
        N += 1
        spikes[N] = t
        t += rand_ISI()
    end
    resize!(spikes, N)
end
# ¹ For an idea of the expected overhead of this: for r = 100 Hz and T = 10 minutes, the
#   expected N is 60000, and at P(N > max_N) = 1E-14, max_N is 61855.
