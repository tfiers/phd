
using ThreadLogging

work(item) = begin
    for i in 1:3
        @info "Work-item $item, step $i"
        sleep(1)
        @info "done"
    end
end

items = collect(1:20)

threaded_foreach(work, items)
