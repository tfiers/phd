module ThreadProgress

using Base.Threads: @threads
using ProgressMeter

function threaded_foreach(f, collection)
    pb = Progress(length(collection))
    @threads for el in collection
        f(el)
        next!(pb)
    end
    finish!(pb)
end

export threaded_foreach

end
