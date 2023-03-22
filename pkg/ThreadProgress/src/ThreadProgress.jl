module ThreadProgress

using Base.Threads
using ProgressMeter
using Logging

logdir = joinpath(homedir(), ".julia", "tfiers", "logs")

function threaded_foreach(f, collection)
    @info "Using $(nthreads()) threads"

    # For user logging: redirect to sep files, and not our main term
    mkpath(logdir)
    thread_ids = 1:nthreads()
    logfiles = [joinpath(logdir, "thread_$i.txt") for i in thread_ids]
    @info "Threads will log to: " logfiles
    logstreams = open.(logfiles, "w+")
    loggers = SimpleLogger.(logstreams)

    # Progress meter
    pb = Progress(length(collection))
    update!(pb, 0)  # Force a draw already

    @threads for el in collection
        i = threadid()
        l = loggers[i]
        with_logger(l) do
            f(el)
        end
        next!(pb)
        flush(logstreams[i])
    end

    finish!(pb)
    close.(logstreams)
    return nothing
end


export threaded_foreach

end
