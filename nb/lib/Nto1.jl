
using WithFeedback

@withfb using Revise
@withfb using Units, Nto1AdEx, ConnectionTests, ConnTestEval, MemDiskCache

using Random
using ProgressMeter
using DefaultApplication

include("util.jl")
prettify_logging_in_IJulia()
set_print_precision(3)

# module LibNto1  # module, to prevent inadvertant usage of globals (nb vars) in funcs here
# using Units, Nto1AdEx, ConnectionTests, ProgressMeter
# export get_trains_to_test, test_high_firing_inputs

function get_trains_to_test(
    sim::Nto1AdEx.SimData;
    Nₜ = 100,  # Number of trains of each type, (exc, inh, unc)
    seed = 1,  # For generating unconnected trains (both their frs, and their spikes)
)
    exc_inputs = highest_firing(excitatory_inputs(sim))[1:Nₜ]
    inh_inputs = highest_firing(inhibitory_inputs(sim))[1:Nₜ]
    both = [exc_inputs..., inh_inputs...]
    fr = spikerate.(both)
    # Seed may not be same as seed in sim: otherwise our 'unconnected'
    # trains generated might be same as the real ones generated in sim.
    Random.seed!(sim.seed + seed)
    unconn_frs = sample(fr, Nₜ)
    unconn_trains = [poisson_SpikeTrain(r, sim.duration) for r in unconn_frs]
    return [
        (:exc, exc_inputs),
        (:inh, inh_inputs),
        (:unc, unconn_trains),
    ]
end

ConnectionTests.set_STA_length(20ms)  # Note also: there's no tx delay in our Nto1 AdEx sim.

STA_test(sig, spiketimes) = test_conn(STAHeight(), sig, spiketimes)

function test_inputs(sim::Nto1AdEx.SimData, sig, inputs, test=STA_test)
    rows = []
    for (conntype, trains) in inputs
        descr = string(conntype)
        @showprogress descr for train in trains
            t = test(sig, train.times)
            fr = spikerate(train)
            push!(rows, (; conntype, fr, t))
        end
    end
    return rows
end

test_high_firing_inputs(sim::Nto1AdEx.SimData, sig; Nₜ = 100, seed = 1) = begin
    high_firing_inputs = get_trains_to_test(sim; Nₜ, seed)
    test_inputs(sim, sig, high_firing_inputs)
end


(; Vₛ, Eₗ) = Nto1AdEx

function VI_sig(sim; spike_SNR = 40, spike_height = (Vₛ - Eₗ), seed=1)
    Random.seed!(seed)
    σ = spike_height / spike_SNR
    sig = copy(sim.V)
    sig .+= (σ .* randn(length(sig)))
    sig
end

clip!(sig, p = 99) = begin
    thr = percentile(sig, p)
    clip_at!(sig, thr)
end

clip_at!(sig, thr) = begin
    to_clip = sig .≥ thr
    sig[to_clip] .= thr
    sig
end


# end # module
# using .LibNto1


nothing  # Don't print anything when `include`d.
