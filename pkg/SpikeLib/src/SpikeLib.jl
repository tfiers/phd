module SpikeLib

using UnPack
using MacroTools: striplines, unblock
using DataStructures: SortedSet
using Test  # We use @test instead of @assert as it gives a more useful error message
using StructArrays
using Latexify
using LaTeXStrings
using PartialFunctions
using Chain

include("poisson.jl")
export gen_Poisson_spikes

include("eqparse.jl")
export @eqs

include("latex.jl")
export show_eqs

end
