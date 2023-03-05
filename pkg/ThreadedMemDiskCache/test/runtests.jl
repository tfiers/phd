
using ThreadedMemDiskCache

set_cachedir("2023-05-03__test_ThreadedMemDiskCache")

function run_sim(; N, duration, seed=1)
    println("Actually running `run_sim`")
    sleep(0.3)
    return (; N, seed, duration)
end

sims = CachedFunction(run_sim; duration=500)

sim = sims(; N=9, seed=1)
