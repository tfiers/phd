
function gen_Poisson_spikes(r, T)
    # The number of spikes N in a time interval [0, T] is ~ Poisson(mean = rT)
    # <--> Inter-spike-intervals ~ Exponential(rate = r).
    #
    # We simulate the Poisson process by drawing such ISIs, and accumulating them until we
    # reach T. We cannot predict how many spikes we will have at that point. Hence, we
    # allocate an array long enough to very likely fit all of them, and trim off the unused
    # end upon reaching T.
    #
    max_N = cquantile(Poisson(r*T), 1e-14)  # complementary quantile. [1]
    spikes = Vector{Float64}(undef, max_N)
    ISI_distr = Exponential(inv(r))         # Parametrized by scale = 1 / rate
    N = 0
    t = rand(ISI_distr)
    while t ≤ T
        N += 1
        spikes[N] = t
        t += rand(ISI_distr)
    end
    resize!(spikes, N)
end
# [1] If the provided probability is smaller than ~1e15, we get an error (`Inf`):
#     https://github.com/JuliaStats/Rmath-julia/blob/master/src/qpois.c#L86
#     For an idea of the expected overhead of creating a roomy array: for r = 100 Hz and T =
#     10 minutes, the expected N is 60000, and max_N is 61855 (at P(N > max_N) = 1e-14).
