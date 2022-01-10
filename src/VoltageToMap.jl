module VoltageToMap

using Unitful, PyFormattedStrings

include("util.jl")
include("signal.jl")
include("display.jl")

export Signal, duration

end
