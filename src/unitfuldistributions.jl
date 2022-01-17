using Random: AbstractRNG
using Unitful: Units, Quantity
using Distributions: Distribution, VariateForm, ValueSupport
import Distributions: pdf, cdf, rand
import Distributions: Exponential, Normal, LogNormal, Gamma

struct UnitfulDistribution{F<:VariateForm,S<:ValueSupport} <: Distribution{F,S}
    distribution::Distribution{F,S}
    units::Units
end
# Note that we don't make UDist a subtype of it's wrapped distr.
# We only subtype the general type, to make it Sampleable.

const UDist = UnitfulDistribution

pdf(d::UDist, x::Quantity) = pdf(d.distr, x / d.units) / d.units
cdf(d::UDist, x::Quantity) = cdf(d.distr, x / d.units)
rand(rng::AbstractRNG, d::UDist) = rand(rng, d.distribution) * d.units

# Type piracy warnings, cause neither Dists nor Quantity are defined by us.
# Disabled with setting "julia.lint.pirates".
Exponential(λ::Quantity)                   = UDist(Exponential(ustrip(λ)), unit(λ))
Normal(μ::Quantity, σ::Quantity)           = UDist(Normal(ustrip(μ), ustrip(σ)), unit(μ))
LogNormal(μ::Real, σ::Real, units::Units)  = UDist(LogNormal(μ, σ), units)
Gamma(α::Real, θ::Quantity)                = UDist(Gamma(α, ustrip(θ)), unit(θ))
