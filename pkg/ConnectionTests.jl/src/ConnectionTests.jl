"""
Given spiketimes and voltage recordings,
infer neural network connectivity at the synapse level.
"""
module ConnectionTests

using WithFeedback


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

Note that `method` must be an *instantiated* struct, not the type itself.
"""
function test_conn end

# We have general argument names 'xs' and 'ys' here
# to fit both the (v, times), and the (real_STA, shuffled_STAs) forms
# of test_conn.
test_conns(m::ConnTestMethod, xs, ys) = begin
    N = length(xs)
    tvals = Vector{Float64}(undef, N)
    for (i, (x, y)) in enumerate(zip(xs, ys))
        @withfb "Testing connection $i / $N" begin
            tvals[i] = test_conn(m, x, y)
        end
    end
    return tvals
end



Δt::Float64 = 0.1*1e-3  # In seconds. = 0.1 ms
set_Δt(x) = (global Δt = x)

STA_length::Int = 1000  # = 100 ms at 0.1 ms Δt
set_STA_length(x) = (global STA_length = x)



include("fit_upstroke.jl")
export FitUpstroke

include("spike-trig-avg.jl")
export STABasedConnTest, STAHeight, TemplateCorr, TwoPassCorrTest
export calc_STA, calc_shuffle_STAs
export get_STAs_for_template

export test_conn, test_conns


end
