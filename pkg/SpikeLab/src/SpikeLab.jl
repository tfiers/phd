module SpikeLab

include("poisson.jl")
export gen_Poisson_spikes

include("eqparse.jl")
export @eqs

include("latex.jl")
export show_eqs

end
