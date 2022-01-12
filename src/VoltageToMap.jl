module VoltageToMap

include("util.jl")

include("signal.jl")
export Signal, duration

include("plot.jl")
include("style.jl")
export plot, set!, savefig, style

include("show.jl")

end
