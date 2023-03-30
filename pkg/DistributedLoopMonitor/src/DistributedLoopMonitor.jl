module DistributedLoopMonitor

export @start_workers, distributed_foreach

using Distributed
using WithFeedback


macro start_workers(N = Sys.CPU_THREADS - 1)
    quote
        # Overwrite the "From worker x: " printing
        Distributed.redirect_worker_output(id, io) =
            DistributedLoopMonitor._redirect_worker_output(id, io)

        _start_workers($N)

        @everywhere using DistributedLoopMonitor
        # This is needed for some reason.
        # Hence the necessity for a macro, also.

    end
end

m = nothing

_redirect_worker_output(id, io) = begin
    global m
    t = @async while !eof(io)
        line = readline(io)
        handle_message(m, id, line)
    end
    errormonitor(t)
end

_start_workers(N) = begin
    already_running = nprocs() - 1
    #   ..and not nworkers(), which is
    #   `1` both before and after `addprocs(1)`
    ns = N - already_running
    @withfb "Initializing workers" addprocs(ns)
end

include("printing.jl")

distributed_foreach(f, collection) = begin
    N = length(collection)
    global m = LoopMonitor(N)
    println()
    start!(m)
    @sync @distributed for el in collection
        f(el)
        @spawnat 1 item_done!(m)
    end
    done!(m)
end

end
