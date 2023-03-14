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

Δt::Float64 = 0.1*1e-3  # 0.1 ms

set_Δt(x) = (global Δt = x)

export test_conn, set_Δt

include("winpool_linreg.jl")
export WinPoolLinReg

end
