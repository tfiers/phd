module PhDPlots

using Units
using Sciplotlib


const color_exc = C0
const color_inh = C1
const color_unconn = Gray(0.3)


include("signal.jl")
export plotsig, plotSTA


using IJulia
include("nb_retina_fix.jl")


end # module PhDPlots
