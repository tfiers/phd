module DistributedLoopMonitor

using Distributed
using WithFeedback

export @start_workers, distributed_foreach
export @everywhere


macro start_workers(N = Sys.CPU_THREADS - 1)
    quote
        # Overwrite the "From worker x: " printing
        Distributed.redirect_worker_output(id, io) =
            DistributedLoopMonitor._redirect_worker_output(id, io)

        _start_workers($N)

        DistributedLoopMonitor._create_printer()

        @everywhere using DistributedLoopMonitor
        # This is needed for some reason.
        # Hence the necessity for a macro, also.
        # (together with the Distributed method override above;
        #  otherwise "incremental compilation may be broken").
    end
end

include("printing.jl")

p = nothing

_create_printer() = (global p = OverviewPrinter())

_redirect_worker_output(id, io) = begin
    t = @async while !eof(io)
        line = readline(io)
        handle_message(p, id, line)
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

m = nothing

distributed_foreach(f, collection) = begin
    N = length(collection)
    global m = LoopMonitor(N, p)
        # Needed for the item_done below to work.
    println()
    start!(m)
    @sync @distributed for el in collection
        f(el)
        @spawnat 1 item_done!(m)
    end
    done!(m)
end

end
