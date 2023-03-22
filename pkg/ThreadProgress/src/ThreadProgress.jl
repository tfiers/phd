module ThreadProgress

using Base.Threads
using Logging

mutable struct ThreadLogger4 <: AbstractLogger
    status           ::Vector{String}
    first_draw_done  ::Bool
    num_el           ::Int
    @atomic num_done ::Int

    ThreadLogger4(num_threads, num_el) = new(
        fill("", num_threads),
        false,
        num_el,
        0,
    )
end

next!(l::ThreadLogger4) = begin
    @atomic l.num_done += 1
    threadid() == 1 && redraw(l)
end

Logging.min_enabled_level(::ThreadLogger4) = Logging.Debug
Logging.shouldlog(::ThreadLogger4, args...) = true
Logging.handle_message(
    l::ThreadLogger4, lvl::LogLevel, msg, args...; kwargs...
) = begin
    i = threadid()
    l.status[i] = msg
    if i == 1
        if !l.first_draw_done
            draw(l)
            l.first_draw_done = true
        else
            redraw(l)
        end
    end
end

draw(l::ThreadLogger4) = begin
    println("Items done: ", l.num_done, " / ", l.num_el)
    println()
    for (i, msg) in enumerate(l.status)
        println("Thread $i: ", msg)
    end
end
nlines(l::ThreadLogger4) = 2 + length(l.status)

redraw(l::ThreadLogger4) = (clear(l); draw(l))

clear(l::ThreadLogger4) =
    for _ in 1:nlines(l)
        prevline()
        clearline()
    end

# https://discourse.julialang.org/t/19549/3
# and https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_(Control_Sequence_Introducer)_sequences
const CSI = "\u1b["
prevline() = print(CSI*"1F")  # Go to start of previous line
clearline() = print(CSI*"0K")  # Clear to eol


function threaded_foreach(f, collection)
    nt = nthreads()
    @info "Using $nt threads"
    N = length(collection)
    l = ThreadLogger4(nt, N)
    @threads for el in collection
        with_logger(l) do
            f(el)
            next!(l)
        end
    end
    redraw(l)
    println("Done")
    return nothing
end


export threaded_foreach

end
