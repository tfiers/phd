"""
Given spiketimes and voltage recordings,
infer neural network connectivity at the synapse level.
"""
module ConnectionTests


abstract type ConnTestMethod end

"""
    test_conn(
        method::ConnTestMethod,
        voltage,
        spiketimes
    )

Calculate a 'connected-ness' measure, `c`.

The larger `c`'s absolute value, the more likely there is a direct
synaptic connection from the neuron with the given `spiketimes` to the
neuron with the given `voltage` signal. Positive `c` indicates an
excitatory connection, negative `c` an inhibitory one.
"""
function test_conn end

test_conns(m::ConnTestMethod, xs, ys) = [
    test_conn(m, x, y)
    for (x, y) in zip(xs, ys)
]


Δt::Float64 = 0.1*1e-3  # In seconds. = 0.1 ms
set_Δt(x) = (global Δt = x)

STA_length::Int = 1000  # = 100 ms at 0.1 ms Δt
set_STA_length(x) = (global STA_length = x)



export test_conn, test_conns

include("fit_upstroke.jl")
export FitUpstroke

include("spike-trig-avg.jl")
export STABasedConnTest, STAHeight, TemplateCorr, TwoPassCorrTest

end
