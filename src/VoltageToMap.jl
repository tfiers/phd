module VoltageToMap

using FilePaths: @p_str

include(p"myplotlib/imports.jl")
include(p"myplotlib/plot.jl"); export plot
include(p"myplotlib/set.jl"); export set, legend, hylabel
include(p"myplotlib/colors.jl"); export mix, lighten, darken, toRGBAtuple, deemph, lightgrey,
                                        C0, C1, C2, C3, C4, C5, C6, C7, C9, C10, mplcolors
include(p"myplotlib/style.jl"); export mplstyle

include("signal.jl"); export Signal, duration
include("show.jl")

end
