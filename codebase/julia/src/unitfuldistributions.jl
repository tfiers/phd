using Random
using Unitful
using Unitful: Units
using Distributions

import Random: rand
import Distributions: pdf, cdf
import Distributions: Exponential, Normal, LogNormal, Gamma


struct UnitfulDistribution{D <: Distribution, U <: Units}
    distribution::D
    units::U
end


pdf(d::UnitfulDistribution, x::Quantity) = pdf(d.distribution, (x / d.units) |> NoUnits) / d.units
cdf(d::UnitfulDistribution, x::Quantity) = cdf(d.distribution, (x / d.units) |> NoUnits)

# The Random extension API.
function rand(rng::AbstractRNG, sampler::Random.SamplerTrivial{<:UnitfulDistribution})
    d::UnitfulDistribution = sampler[]
    return rand(rng, d.distribution) * d.units
end
# To make sure arrays returned by `rand` do not have type `Any`.
Base.eltype(::Type{UnitfulDistribution{D,U}}) where {D,U} =
    Quantity{eltype(D),dimension(U()),U}

# Allow eg `pdf.(d, multiple_values)`.
Broadcast.broadcastable(d::UnitfulDistribution{<:UnivariateDistribution}) = Ref(d)



# Type piracy warnings, cause neither Distrs nor Quantity are defined by us.
# Disabled with vscode setting "julia.lint.pirates".
Exponential(θ::Quantity) = UnitfulDistribution(
    Exponential(ustrip(θ)),
    unit(θ),
)
Normal(μ::Quantity, σ::Quantity) = UnitfulDistribution(
    Normal(ustrip(μ), ustrip(σ)),
    unit(μ),
)
LogNormal(μ::Real, σ::Real, units::Units) = UnitfulDistribution(
    LogNormal(μ, σ),
    units,
)
Gamma(α::Real, θ::Quantity) = UnitfulDistribution(
    Gamma(α, ustrip(θ)),
    unit(θ),
)
