module ThreadProgress

using Base.Threads
using Logging

mutable struct ThreadLogger6 <: AbstractLogger
    num_el           ::Int
    @atomic num_done ::Int
    msgs             ::Vector{String}
    redraw_channel   ::Channel{Bool}

    ThreadLogger6(num_el) = new(
        num_el,
        0,
        fill("", nthreads()),
        Channel{Bool}(1),  # Only one redraw can be in queue
    )
end

queue_redraw!(l::ThreadLogger6) =
    if isempty(l.redraw_channel)
        # If not empty, there's already a redraw queued:
        # no need to queue another. If it is empty: redraw pls
        put!(l.redraw_channel, true)
    end

redraw_on_cue(l::ThreadLogger6) = begin
    draw(l)
    while isopen(l.redraw_channel)
        take!(l.redraw_channel)  # Blocks when empty
        redraw(l)
    end
end

done!(l::ThreadLogger6) = begin
    close(l.redraw_channel)
    sleep(0.1)  # For if there is a redraw in progress
    redraw(l)
end

draw(l::ThreadLogger6) = begin
    println("Items done: ", l.num_done, " / ", l.num_el)
    println()
    for (i, msg) in enumerate(l.msgs)
        println("Thread $i: ", msg)
    end
end
nlines(l::ThreadLogger6) = 2 + length(l.msgs)

redraw(l::ThreadLogger6) = (clear(l); draw(l))

clear(l::ThreadLogger6) =
    for _ in 1:nlines(l)
        prevline()
        clearline()
    end

# https://discourse.julialang.org/t/19549/3
# and https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_(Control_Sequence_Introducer)_sequences
const CSI = "\u1b["
prevline() = print(CSI*"1F")  # Go to start of previous line
clearline() = print(CSI*"0K")  # Clear to eol


item_done!(l::ThreadLogger6) = begin
    @atomic l.num_done += 1
    queue_redraw!(l)
end


Logging.min_enabled_level(::ThreadLogger6) = Logging.Debug
Logging.shouldlog(::ThreadLogger6, args...) = true
Logging.handle_message(
    l::ThreadLogger6, lvl::LogLevel, msg, args...; kwargs...
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



function threaded_foreach(f, collection)
    N = length(collection)
    l = ThreadLogger6(N)
    println()
    @async redraw_on_cue(l)
    @threads :static for el in collection
        with_logger(l) do
            f(el)
        end
        item_done!(l)
    end
    done!(l)
end


export threaded_foreach

end
