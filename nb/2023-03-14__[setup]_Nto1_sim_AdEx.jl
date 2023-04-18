# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.4
#   kernelspec:
#     display_name: Julia 1.9.0-beta3
#     language: julia
#     name: julia-1.9
# ---

# # 2023-03-14 • [setup] N-to-1 simulation of AdEx neuron

# This is a script, to be 'imported' (included, run) by other notebooks.

# Based on `2023-02-07__AdEx_Nto1`.

# cd(joinpath(homedir(), "phd", "pkg" , "SpikeWorks"))
# run(`git switch metdeklak`)
# ↪ Not doing here, as multiprocs on same git repo crashes

using WithFeedback

@withfb using Distributed
@withfb using Revise
@withfb using SpikeWorks
@withfb using SpikeWorks.Units
@withfb using ConnectionTests
@withfb using DataFrames

nworkers() > 1 && WithFeedback.nested()

@typed begin
    # AdEx LIF neuron params (cortical RS)
    C  = 104  * pF
    gₗ = 4.3  * nS
    Eₗ = -65  * mV
    Vₜ = -52  * mV
    Δₜ = 0.8  * mV
    Vₛ =   0  * mV
    Vᵣ = -53  * mV
    a  = 0.8  * nS
    b  =  65  * pA
    τw =  88  * ms
    # Conductance-based synapses
    Eₑ =   0 * mV
    Eᵢ = -80 * mV
    τ  =   7 * ms
end

# -
# ### Simulated variables and their initial values

const x₀ = (
    # AdEx variables
    v   = Vᵣ,      # Membrane potential
    w   = 0 * pA,  # Adaptation current
    # Synaptic conductances g
    gₑ  = 0 * nS,  # = Sum over all exc. synapses
    gᵢ  = 0 * nS,  # = Sum over all inh. synapses
)

# ### Differential equations:
# calculate time derivatives of simulated vars
# (and store them "in-place", in `Dₜ`).

function f!(Dₜ, vars)
    v, w, gₑ, gᵢ = vars

    # Conductance-based synaptic current
    Iₛ = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    # AdEx 2D system
    Dₜ.v = (-gₗ*(v-Eₗ) + gₗ*Δₜ*exp((v-Vₜ)/Δₜ) - Iₛ - w) / C
    Dₜ.w = (a*(v-Eₗ) - w) / τw

    # Synaptic conductance decay
    Dₜ.gₑ = -gₑ / τ
    Dₜ.gᵢ = -gᵢ / τ
end

# ### Spike discontinuity

has_spiked(vars) = (vars.v > Vₛ)

function on_self_spike!(vars)
    vars.v = Vᵣ
    vars.w += b
end
# -

# ### Conductance-based AdEx neuron

const coba_adex_neuron = NeuronModel(x₀, f!; has_spiked, on_self_spike!);


# ### More parameters, and input spikers

using SpikeWorks: LogNormal

# Firing rates λ for the Poisson inputs
const fr_distr = LogNormal(median = 4Hz, g = 2)

@typed begin
    Δt = 0.1ms
    EIratio = 4//1
end

using SpikeWorks: newsim, run!

using Random

function run_sim(; N, duration, seed, δ_nS)
    # δ_nS: Strength, in nS, of each incoming spike:
    #       How much does it increase the postsynaptic conductance, g.
    Random.seed!(seed)
    firing_rates = rand(fr_distr, N)
    input_IDs = 1:N
    inputs = [
        Nto1Input(ID, poisson_SpikeTrain(λ, duration))
        for (ID, λ) in zip(input_IDs, firing_rates)
    ]
    (; Nₑ, Nᵢ) = EIMix(N, EIratio)
    neuron_type(ID) = (ID ≤ Nₑ) ? :exc : :inh
    Δgₑ = δ_nS * nS
    Δgᵢ = δ_nS * nS * EIratio
    on_spike_arrival!(vars, spike) =
        if neuron_type(source(spike)) == :exc
            vars.gₑ += Δgₑ
        else
            vars.gᵢ += Δgᵢ
        end

    sim = newsim(coba_adex_neuron, inputs, on_spike_arrival!, Δt)
    run!(sim)

    _spiketimes(input::Nto1Input) = input.train.spiketimes

    # The names of this NamedTuple are the API.
    # They are stable/versioned.
    # The weirdness on the RHS is opaque.
    simdata = (;
        spiketrains   = _spiketimes.(inputs),
        voltsig       = sim.rec.v,
        spikerate     = SpikeWorks.spikerate(sim),
        input_types   = neuron_type.(input_IDs),
        sim_duration  = duration,
        firing_rates, input_IDs, N, seed, δ_nS
    )
    return simdata
end

# An alias for human readability.
# We don't make it a proper (concrete) type, as we want to be able to
# change it, without having to restart Julia.
const SimData = NamedTuple

"Spiking rate of the output neuron in an Nto1 sim"
spikerate(sd::SimData) = sd.spikerate

"Voltage signal of the output neuron in an Nto1 sim"
voltsig(sd::SimData) = sd.voltsig

"List of spiketime-lists"
spiketrains(sd::SimData) = sd.spiketrains

"Neuron type (exc or inh) of each input spiker"
input_types(sd::SimData) = sd.input_types

sim_duration(sd::SimData) = sd.sim_duration



# --- Caching ---

@withfb using MemDiskCache

prefixdir = "2023-03-14__Nto1_AdEx"

kw_order = [:N, :Nᵤ, :δ_nS, :duration, :seed, :batch_size, :part]

sims = CachedFunction(run_sim, prefixdir, kw_order)

if @isdefined(warmup) && warmup
    @withfb "Warming up sim & JLD2 funcs" begin
        # For multiproccessing: diff processes can't write to same JLD2 file.
        # So to avoid crash: process id as seed (which is in filename).
        kw = (; N=5, δ_nS=5.0, duration=1seconds, seed=100+myid())
        rm_from_disk(sims; kw...)
        sims(; kw...)
        rm_from_memcache!(sims; kw...)
        sims(; kw...)
    end
end



# ---

gen_unconnected_trains(sd::SimData, num) = begin
    Random.seed!(sd.seed + num)
        # If seed where the same as sim's seed, and N = Nᵤ
        # we'd generate the same spike trains for the unconnected as the connected.
    firing_rates = rand(fr_distr, num)
    T = sd.sim_duration
    trains = [SpikeWorks.poisson_spikes(r, T) for r in firing_rates]
end
# This is cheap -- and with the seed, reproducible.
# So caching is a waste of code. We instead regen, everytime
# the below is queried.

simdata_with_unconns(; Nᵤ, simkw...) = begin
    sd = sims(; simkw...)
    trains_conn = spiketrains(sd)
    trains_unconn = gen_unconnected_trains(sd, Nᵤ)
    trains = [
        trains_conn...,
        trains_unconn...,
    ]
    conntypes = [
        input_types(sd)...,
        fill(:unc, Nᵤ)...,
    ]
    return (; sd..., trains_conn, trains_unconn, trains, conntypes)
end

# Another human readability alias.
const AugmentedSimData = NamedTuple

all_spiketrains(sd::AugmentedSimData) = sd.trains
connection_types(sd::AugmentedSimData) = sd.conntypes




# ---

batch_size = 300  # Number of STAs. One STA is ≈ 0.8 MB

calc_all_STAs(; batch_size, part, simkw...) = begin
    sd = simdata_with_unconns(; simkw...)
    v = voltsig(sd)
    trains = subset(all_spiketrains(sd), batch_size, part)
    (; reals, shufs) = ConnectionTests.calc_all_STAs(v, trains)
end

STA_sets = CachedFunction(calc_all_STAs, prefixdir, kw_order, mem = false)
# No storing in memory: too large to fit.


subset(vec, batch_size::Integer, part::Integer) = begin
    N = length(vec)
    start = (part-1) * batch_size + 1
    stop = part * batch_size
    if stop > N
        stop = N
    end
    return vec[start:stop]
end

for_each_STA_batch(f, N_total, batch_size, simkw) = begin
    for part in parts(N_total, batch_size)
        reals, shufs = STA_sets(; simkw..., batch_size, part)
        f(reals, shufs)
    end
end

parts(N, batch_size) = 1:ceil(Int, N / batch_size)




# ---

conntest_methods = Dict(
    :fit_upstroke     => ConnectionTests.FitUpstroke(),
    :STA_height       => ConnectionTests.STAHeight(),
    :STA_corr_2pass   => ConnectionTests.TwoPassCorrTest(),
    # :STA_modelfit   => test_conn_STA_modelfit,
)

function conntest_all(; method, simkw...)
    # (`simkw` includes `Nᵤ` here)
    m = conntest_methods[method]
    sd = simdata_with_unconns(; simkw...)
    spiketime_vecs = all_spiketrains(sd)
    N_total = length(spiketime_vecs)
    descr = "[$(typeof(m))]"
    if m isa STAHeight
        tvals = Float64[]
        for_each_STA_batch(N_total, batch_size, simkw) do reals, shufs
            t₀ = time()
            @withfb descr (ts = test_conns(m, reals, shufs))
            append!(tvals, ts)
            if time() - t₀ > 10
                @withfb GC.gc()
            end
        end
    elseif m isa TwoPassCorrTest
        template = zeros(Float64, ConnectionTests.STA_length)
        for_each_STA_batch(N_total, batch_size, simkw) do reals, shufs
            exc_STAs = get_STAs_for_template(m, reals, shufs)
            if !isempty(exc_STAs)
                template += sum(exc_STAs)
            end
        end
        template ./= N_total
        tvals = Float64[]
        m₂ = TemplateCorr(template)
        for_each_STA_batch(N_total, batch_size, simkw) do reals, shufs
            @withfb descr (ts = test_conns(m₂, reals, shufs))
            append!(tvals, ts)
        end
    else
        v = voltsig(sd)
        vs = fill(v, N_total)
        @withfb descr (tvals = test_conns(m, vs, spiketime_vecs))
    end
    table = DataFrame(;
        t = tvals,
        conntype = connection_types(sd),
        spikerate = length.(spiketime_vecs) ./ sim_duration(sd),
    )
    return table
end

conntest_tables = CachedFunction(conntest_all, prefixdir, kw_order)
