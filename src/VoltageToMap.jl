module VoltageToMap

using FilePaths: @p_str

include(p"plot/imports.jl")
include(p"plot/plot.jl"); export plot
include(p"plot/set.jl"); export set, legend, ylabel, deemph
include(p"plot/colors.jl"); export mix, lighten, darken, toRGBAtuple,
                                   C0, C1, C2, C3, C4, C5, C6, C7, C9, C10, mplcolors
include(p"plot/style.jl"); export mplstyle

include("signal.jl"); export Signal, duration
include("show.jl")

end
