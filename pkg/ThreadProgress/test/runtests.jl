
using ThreadProgress

work(el) = begin
    for i in 1:3
        @info "Work $el, step $i"
        sleep(1)
        @info "done"
    end
end

threaded_foreach(collect(1:20)) do (el)
    work(el)
end
