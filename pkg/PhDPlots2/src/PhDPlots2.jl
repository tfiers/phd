module PhDPlots2

using Units
using Sciplotlib2


const color_exc = C0
const color_inh = C1
const color_unconn = Gray(0.3)


include("signal.jl")
export plotsig, plotSTA


using IJulia
using PythonCall
include("nb_retina_fix.jl")


end # module PhDPlots
