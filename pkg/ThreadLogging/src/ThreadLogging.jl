module ThreadLogging

using Base.Threads
using Logging

mutable struct ThreadLogger <: AbstractLogger
    @atomic header   ::String
    msgs             ::Vector{String}
    redraw_channel   ::Channel{Bool}

    ThreadLogger() = new(
        "",
        fill("", nthreads()),
        Channel{Bool}(1),  # Only one redraw can be in queue
    )
end

update_header!(l::ThreadLogger, h) = begin
    @atomic l.header = h
    queue_redraw!(l)
end

Logging.min_enabled_level(::ThreadLogger) = Logging.Debug
Logging.shouldlog(::ThreadLogger, args...) = true
Logging.handle_message(
    l::ThreadLogger, lvl::LogLevel, msg, args...; kwargs...
) = begin
    i = threadid()
    l.msgs[i] = clean(msg)
    queue_redraw!(l)
end

clean(msg) = truncate(replace(msg, "\n"=>" "))

truncate(str, n = 20) =
    if length(str) > n
        str[1:(n-1)] * "…"
    else
        str
    end

queue_redraw!(l::ThreadLogger) =
    if isempty(l.redraw_channel)
        # If not empty, there's already a redraw queued:
        # no need to queue another. If it is empty: redraw pls
        put!(l.redraw_channel, true)
    end

redraw_on_cue(l::ThreadLogger) = begin
    draw(l)
    while isopen(l.redraw_channel)
        take!(l.redraw_channel)  # Blocks when empty
        redraw(l)
    end
end

start!(l::ThreadLogger) = @async redraw_on_cue(l)

done!(l::ThreadLogger) = begin
    close(l.redraw_channel)
    sleep(0.1)  # For if there is a redraw in progress
    redraw(l)
end

draw(l::ThreadLogger) = begin
    println(l.header)
    println()
    for (i, msg) in enumerate(l.msgs)
        println("Thread $i: ", msg)
    end
end
nlines(l::ThreadLogger) = 2 + length(l.msgs)

redraw(l::ThreadLogger) = (clear(l); draw(l))

clear(l::ThreadLogger) =
    for _ in 1:nlines(l)
        prevline()
        clearline()
    end

# https://discourse.julialang.org/t/19549/3
# and https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_(Control_Sequence_Introducer)_sequences
const CSI = "\u1b["  # Control Sequence Introducer
prevline() = print(CSI*"1F")  # Go to start of previous line
clearline() = print(CSI*"0K")  # Clear to eol




mutable struct LoopMonitor
    num_el           ::Int
    @atomic num_done ::Int
    logger           ::ThreadLogger

    LoopMonitor(num_el) = begin
        m = new(num_el, 0, ThreadLogger())
        update_header!(m)
        return m
    end
end

update_header!(m::LoopMonitor) =
    update_header!(m.logger, "Items done: $(m.num_done) / $(m.num_el)")

item_done!(m::LoopMonitor) = begin
    @atomic m.num_done += 1
    update_header!(m)
end

start!(m::LoopMonitor) = start!(m.logger)
done!(m::LoopMonitor) = done!(m.logger)



function threaded_foreach(f, collection)
    N = length(collection)
    m = LoopMonitor(N)
    println()
    start!(m)
    @threads :static for el in collection
        with_logger(m.logger) do
            f(el)
        end
        item_done!(m)
    end
    done!(m)
end


export threaded_foreach, ThreadLogger, LoopMonitor

end
