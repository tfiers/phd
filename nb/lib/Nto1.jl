
using WithFeedback

@withfb using Revise
@withfb using Units, Nto1AdEx, ConnectionTests, ConnTestEval, MemDiskCache

using Random
using ProgressMeter
using DefaultApplication

include("util.jl")
prettify_logging_in_IJulia()
set_print_precision(3)

function get_trains_to_test(
    sim::Nto1AdEx.SimData,
    Nₜ = 100,  # ..number of trains of each type, (exc, inh, unc)
    seed = 1,
)
    exc_inputs = highest_firing(excitatory_inputs(sim))[1:Nₜ]
    inh_inputs = highest_firing(inhibitory_inputs(sim))[1:Nₜ]
    both = [exc_inputs..., inh_inputs...]
    fr = spikerate.(both)
    # Seed may not be same as seed in sim: otherwise our 'unconnected'
    # trains generated might be same as the real ones generated in sim.
    Random.seed!(sim.seed + seed)
    unconn_frs = sample(fr, Nₜ)
    unconn_trains = [poisson_SpikeTrain(r, duration) for r in unconn_frs]
    return [
        (:exc, exc_inputs),
        (:inh, inh_inputs),
        (:unc, unconn_trains),
    ]
end

nothing;
