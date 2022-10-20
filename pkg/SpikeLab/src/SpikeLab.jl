module SpikeLab

using Reexport
@reexport using Distributions

include("poisson.jl")
export gen_Poisson_spikes

include("distributions.jl")
# Don't export LogNormal, to not conflict with Distributions.jl
# Instead, use `SpikeLab.LogNormal` to use our parametrization.

include("eqparse.jl")
export @eqs

include("latex.jl")
export show_eqs

end
