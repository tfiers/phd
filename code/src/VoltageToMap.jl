module VoltageToMap

using Reexport

@reexport using MyToolbox
@reexport using Distributions  # Sample from lognormal, exponential, ….

"""
`μ` and `σ` are mean and standard deviation of the underlying Gaussian.
`μₓ` is the mean of the log of the Gaussian.
"""
function LogNormal_with_mean(μₓ, σ)
    μ = log(μₓ) - σ^2 / 2
    return LogNormal(μ, σ)
end

export LogNormal_with_mean

include("units.jl")
export mega, kilo, milli, centi, micro, nano, pico
export s, seconds, ms, minutes, hours, Hz, cm, mm, μm, um, nm
export μA, uA, nA, pA, volt, mV, nV, mS, nS, ohm, Mohm, uF, μF, nF, pF

end
