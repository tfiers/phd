
using Distributed

using DistributedLoopMonitor

@start_workers(3)

@everywhere function run_sim(N)
    println("Running sim for N=$N")
    sleep(rand(2:5))
    println("Done")
end

@everywhere println("Hello")

Ns = [5, 100, 3300]

distributed_foreach(Ns) do N
    run_sim(N)
end
