
mutable struct OverviewPrinter
    @atomic header   ::String
    msgs             ::Vector{String}
    redraw_channel   ::Channel{Bool}

    OverviewPrinter() = new(
        "",
        fill("", nworkers()),
        Channel{Bool}(1),  # Only one redraw can be in queue
    )
end

update_header!(p::OverviewPrinter, h) = begin
    @atomic p.header = h
    queue_redraw!(p)
end

handle_message(p::OverviewPrinter, worker_id, msg) = begin
    i = findfirst(==(worker_id), workers())
    p.msgs[i] = msg
    queue_redraw!(p)
end

queue_redraw!(p::OverviewPrinter) =
    if isempty(p.redraw_channel)
        # If not empty, there's already a redraw queued:
        # no need to queue another. If it is empty: redraw pls
        put!(p.redraw_channel, true)
    end

redraw_on_cue(p::OverviewPrinter) = begin
    draw(p)
    while isopen(p.redraw_channel)
        take!(p.redraw_channel)  # Blocks when empty
        redraw(p)
    end
end

start!(p::OverviewPrinter) = begin
    @async redraw_on_cue(p)
end

done!(p::OverviewPrinter) = begin
    close(p.redraw_channel)
    sleep(0.1)  # For if there is a redraw in progress
    redraw(p)
end

draw(p::OverviewPrinter) = begin
    println(p.header)
    println()
    for (id, msg) in zip(workers(), p.msgs)
        println(truncate("Worker $id: $msg"))
    end
    flush(stdout)
end
nlines(p::OverviewPrinter) = 2 + length(p.msgs)

truncate(msg, N = termwidth()) =
    length(msg) > N ? msg[1:(N-1)] * "…" : msg

termwidth() = displaysize(stdout)[2]  # (lines, cols)

redraw(p::OverviewPrinter) = (clear(p); draw(p))

clear(p::OverviewPrinter) =
    for _ in 1:nlines(p)
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
    printer          ::OverviewPrinter

    LoopMonitor(num_el, printer = OverviewPrinter()) = begin
        m = new(num_el, 0, printer)
        update_header!(m)
        return m
    end
end

update_header!(m::LoopMonitor) =
    update_header!(m.printer, "Items done: $(m.num_done) / $(m.num_el)")

handle_message(m::LoopMonitor, wid, msg) = handle_message(m.printer, wid, msg)

item_done!(m::LoopMonitor) = begin
    @atomic m.num_done += 1
    update_header!(m)
end

start!(m::LoopMonitor) = start!(m.printer)
done!(m::LoopMonitor) = done!(m.printer)
