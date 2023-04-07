module DistributedLoopMonitor

using Distributed
using WithFeedback

export @start_workers, distributed_foreach
export kill_stray_worker_procs

# re-
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
    isnothing(p) && error("Call `@start_workers` first")
    N = length(collection)
    global m = LoopMonitor(N, p)
        # `global` needed for the `item_done` below to work.
    T = eltype(collection)
    jobs = RemoteChannel(()->Channel{T}(Inf))
    for el in collection
        put!(jobs, el)
    end
    println()
    start!(m)
    @sync begin
        for i in workers()
            @spawnat i begin
                while isready(jobs)
                    el = take!(jobs)
                    f(el)
                    @spawnat 1 item_done!(m)
                end
                println("No more jobs")
            end
        end
    end
    done!(m)
end

kill_stray_worker_procs() = begin
    Sys.islinux() || return
    # If a previous run was exited forcefully,
    # worker processes are still around, hogging memory.
    pattern = "julia .* --worker"
    if success(run(`pgrep -f $pattern`, wait=false))
        println("Julia worker processes to terminate:")
        println(read(`pgrep -f $pattern`, String))
        run(`pkill -f $pattern`)
    end
end

end
