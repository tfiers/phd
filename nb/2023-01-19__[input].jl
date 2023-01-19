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
#     display_name: Julia 1.8.1
#     language: julia
#     name: julia-1.8
# ---

# # 2023-01-19 • [input] to 'Fit a line'

# A distillation of `2022-10-24 • N-to-1 with lognormal inputs`,\
# for use in `2023-01-19 • Fit a line`; so that that notebook can remain concise.

# ## Imports

# + tags=[]
#
# -

@showtime using Revise

@showtime using MyToolbox
@showtime using SpikeWorks
@showtime using Sciplotlib
@showtime using VoltoMapSim

# + [markdown] tags=[]
# ## Start
# -

# ### Neuron-model parameters

# + tags=[]
@typed begin
    # Izhikevich params
    C  =  100    * pF        # Cell capacitance
    k  =    0.7  * (nS/mV)   # Steepness of parabola in v̇(v)
    vₗ = - 60    * mV        # Resting ('leak') membrane potential
    vₜ = - 40    * mV        # Spiking threshold (when no syn. & adaptation currents)
    a  =    0.03 / ms        # Reciprocal of time constant of adaptation current `u`
    b  = -  2    * nS        # (v-vₗ)→u coupling strength
    vₛ =   35    * mV        # Spike cutoff (defines spike time)
    vᵣ = - 50    * mV        # Reset voltage after spike
    Δu =  100    * pA        # Adaptation current inflow on self-spike
    # Conductance-based synapses
    Eₑ =   0 * mV            # Reversal potential at excitatory synapses
    Eᵢ = -80 * mV            # Reversal potential at inhibitory synapses
    τ  =   7 * ms            # Time constant for synaptic conductances' decay
end;
# -

# ### Simulated variables and their initial values

x₀ = (
    # Izhikevich variables
    v   = vᵣ,      # Membrane potential
    u   = 0 * pA,  # Adaptation current
    # Synaptic conductances g
    gₑ  = 0 * nS,  # = Sum over all exc. synapses
    gᵢ  = 0 * nS,  # = Sum over all inh. synapses
);

# ### Differential equations:
# calculate time derivatives of simulated vars  
# (and store them "in-place", in `Dₜ`).

function f!(Dₜ, vars)
    v, u, gₑ, gᵢ = vars

    # Conductance-based synaptic current
    Iₛ = gₑ*(v-Eₑ) + gᵢ*(v-Eᵢ)

    # Izhikevich 2D system
    Dₜ.v = (k*(v-vₗ)*(v-vₜ) - u - Iₛ) / C
    Dₜ.u = a*(b*(v-vₗ) - u)

    # Synaptic conductance decay
    Dₜ.gₑ = -gₑ / τ
    Dₜ.gᵢ = -gᵢ / τ
end;

# ### Spike discontinuity

# + tags=[]
has_spiked(vars) = (vars.v ≥ vₛ)

function on_self_spike!(vars)
    vars.v = vᵣ
    vars.u += Δu
end;
# -

# ### Conductance-based Izhikevich neuron

coba_izh_neuron = NeuronModel(x₀, f!; has_spiked, on_self_spike!);

# ### More parameters, and input spikers

using SpikeWorks.Units
using SpikeWorks: LogNormal

@typed begin
    Δt = 0.1ms
    sim_duration = 10minutes
end

# Firing rates λ for the Poisson inputs

fr_distr = LogNormal(median = 4Hz, g = 2)

@enum NeuronType exc inh

input(;
    N = 100,
    EIratio = 4//1,
    scaling = N,
) = begin
    firing_rates = rand(fr_distr, N)
    input_IDs = 1:N
    inputs = [
        Nto1Input(ID, poisson_SpikeTrain(λ, sim_duration))
        for (ID, λ) in zip(input_IDs, firing_rates)
    ]
    # Nₑ, Nᵢ = groupsizes(EIMix(N, EIratio))
    EImix = EIMix(N, EIratio)
    Nₑ = EImix.Nₑ
    Nᵢ = EImix.Nᵢ
    neuron_type(ID) = (ID ≤ Nₑ) ? exc : inh
    Δgₑ = 60nS / scaling
    Δgᵢ = 60nS / scaling * EIratio
    on_spike_arrival!(vars, spike) =
        if neuron_type(source(spike)) == exc
            vars.gₑ += Δgₑ
        else
            vars.gᵢ += Δgᵢ
        end
    return (;
        firing_rates,
        inputs,
        on_spike_arrival!,
        Nₑ,
    )
end;

using SpikeWorks: Simulation, step!, run!, unpack, newsim,
                  get_new_spikes!, next_spike, index_of_next

new(; kw...) = begin
    ip = input(; kw...)
    s = newsim(coba_izh_neuron, ip.inputs, ip.on_spike_arrival!, Δt)
    (sim=s, input=ip)
end;

# ## Multi sim

# (These Ns are same as in e.g. https://tfiers.github.io/phd/nb/2022-10-11__Nto1_output_rate__Edit_of_2022-05-02.html)

using SpikeWorks: spikerate

sim_duration/minutes

# + tags=[]
using Printf
print_Δt(t0) = @printf("%.2G seconds\n", time()-t0)
macro timeh(ex) :( t0=time(); $(esc(ex)); print_Δt(t0) ) end;
# -

Ns_and_scalings = [
    (5,    2.4),   # => N_inh = 1
    (20,   1.3),
        # orig: 21.
        # But: "pₑ = 0.8 does not divide N = 21 into integer parts"
        # So voila
    (100,  0.8),
    (400,  0.6),
    (1600, 0.5),
    (6500, 0.5),
];
Ns = first.(Ns_and_scalings);

nbname = "2023-01-19__[input]"
# nbname = "2022-10-24__Nto1_with_fixed_lognormal_inputs"
cachekey(N) = "$(nbname)__N=$N";
cachekey(Ns[end])

# +
function runsim(N, scaling)
    println()
    (sim, inp) = new(; N, scaling)
    @show N
    @timeh run!(sim)
    @show spikerate(sim)
    return (; sim, input=inp)
end 

simruns = []
for (N, f) in Ns_and_scalings
    scaling = f*N
    simrun = cached(runsim, (N, scaling), key=cachekey(N))
    push!(simruns, simrun)
end
# -

sims = first.(simruns)
inps = last.(simruns);

Base.summarysize(simruns[6]) / GB

# ### Disentangle

spiketimes(input::Nto1Input) = input.train.spiketimes;

vrec(s::Simulation{<:Nto1System}) = s.rec.v;

# ## Conntest

# +
winsize = 1000

calcSTA(sim, spiketimes) =
    calc_STA(vrec(sim), spiketimes, sim.Δt, winsize);

# +
# @code_warntype calc_STA(vrec(s), st1, s.Δt, winsize)
# all good
# -

# ### Cache STA calc

# +
function calc_STA_and_shufs(spiketimes, sim)
    realSTA = calcSTA(sim, spiketimes)
    shufs = [
        calcSTA(sim, shuffle_ISIs(spiketimes))
        for _ in 1:100
    ]
    (; realSTA, shufs)
end

"calc_all_STAs_and_shufs"
function calc_all_STAz(inputs, sim)
    f(input) = calc_STA_and_shufs(spiketimes(input), sim)
    @showprogress map(f, inputs)
end
calc_all_STAz(simrun) = calc_all_STAz(unpakk(simrun)...);
unpakk(simrun) = (; simrun.input.inputs, simrun.sim);

# out = calc_all_STAz(simruns[1])
# print(Base.summary(out))

# + tags=[]
calc_all_cached(i) = cached(calc_all_STAz, [simruns[i]], key=cachekey(Ns[i]))

out = []
# for i in eachindex(simruns)
#     push!(out, calc_all_cached(i))
# end;
# -

conntype_vec(i) = begin
    sim, inp = simruns[i]
    Nₑ = inp.Nₑ
    N = Ns[i]
    conntype = Vector{Symbol}(undef, N);
    conntype[1:Nₑ]     .= :exc
    conntype[Nₑ+1:end] .= :inh
    conntype
end;

# +
conntestresults(i, teststat = ptp_test; α = 0.05) = begin
    
    f((sta, shufs)) = test_conn(teststat, sta, shufs; α)
    res = @showprogress map(f, out[i])
    df = DataFrame(res)
    df[!, :conntype] = conntype_vec(i)
    df
end;

# conntestresults(1)
# -

using Sciplotlib: plot

spikerate_(spiketimes) = length(spiketimes) / sim_duration;

spikerate_(inp::Nto1Input) = spikerate_(spiketimes(inp));

firing_rates(i) = spikerate_.(spiketimes.(inps[i].inputs));
