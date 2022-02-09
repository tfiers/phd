module VoltageToMap

using Reexport

@reexport using MyToolbox
@reexport using Distributions  # Sample from lognormal, exponential, ….
@reexport using Unitful: mV, Hz, ms, s, minute

@exportn @alias seconds = s

"""
`μ` and `σ` are mean and standard deviation of the underlying Gaussian.
`μₓ` is the mean of the log of the Gaussian.
"""
function LogNormal_with_mean(μₓ, σ)
    μ = log(μₓ / unit(μₓ)) - σ^2 / 2
    LogNormal(μ, σ, unit(μₓ))
end

export LogNormal_with_mean

end
