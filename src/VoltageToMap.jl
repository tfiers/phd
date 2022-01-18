module VoltageToMap

using FilePaths: @p_str

include(p"myplotlib/imports.jl")
include(p"myplotlib/plot.jl")
include(p"myplotlib/set.jl")
include(p"myplotlib/ticks.jl")
include(p"myplotlib/colors.jl")
include(p"myplotlib/style.jl")

include("signal.jl")
include("show.jl")

end
