module VoltageToMap

include("util.jl")

include("signal.jl")
export Signal, duration

include("plot.jl")
export plot, set, legend, ylabel, savefig, lighten, toRGBAtuple
export C0, C1, C2, C3, C4, C5, C6, C7, C9, C10, mplcolors

include("plotstyle.jl")
export mplstyle

include("show.jl")

end
