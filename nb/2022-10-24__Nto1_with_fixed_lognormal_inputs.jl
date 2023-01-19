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

# # 2022-10-24 • N-to-1 with lognormal inputs

# ## Imports

# + tags=[]
#
# -

using Revise

@time using MyToolbox
@time using SpikeWorks
@time using Sciplotlib
@time using VoltoMapSim

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

# +
Δt = 0.1ms      # Sim timestep

sim_duration = 10seconds
sim_duration = 1minute
sim_duration = 10minutes
# -

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

s0 = new().sim

s0.system

# (Look at that parametrization of `on_spike_arrival!` closure :OO)

# ## Sim

@time s = run!(new().sim)

# (So 3.3 seconds for 10 minute simulation with N=100 inputs)

# ## Plot

v_rec = s.rec.v;
Nt = s.stepcounter.N;

@time using PyPlot

# + tags=[]
t = linspace(0, sim_duration, Nt)
plotsig(t, v_rec / mV; tlim=[0,10seconds]);
# -

# ## Multi sim

# (These Ns are same as in e.g. https://tfiers.github.io/phd/nb/2022-10-11__Nto1_output_rate__Edit_of_2022-05-02.html)

using SpikeWorks: spikerate

sim_duration/minutes

# + tags=[]
using Printf
print_Δt(t0) = @printf("%.2G seconds\n", time()-t0)
macro time′(ex) :( t0=time(); $(esc(ex)); print_Δt(t0) ) end;
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
Ns = first.(Ns_and_scalings)
simruns = []
for (N, f) in Ns_and_scalings
    scaling = f*N
    (sim, inp) = new(; N, scaling)
    @show N
    @time′ run!(sim)
    @show spikerate(sim)
    push!(simruns, (; sim, input=inp))
    println()
end

# ### Disentangle

# weird old code. who wrote this?! (oh me)\
# what the hell is that naming. "input.inputs"

inp = simruns[1].input
st1 = inp.inputs[1].train.spiketimes;

spiketimes(input::Nto1Input) = input.train.spiketimes;

s = simruns[1].sim
s.rec.v;

vrec(s::Simulation{<:Nto1System}) = s.rec.v;

# ## Conntest

function conntest_all(inputs, sim)
    f(input) = conntest(spiketimes(input), sim)
    @showprogress map(f, inputs)
end
conntest_all(simrun) = conntest_all(simrun.input.inputs, simrun.sim);

# +
winsize = 1000

calcSTA(sim, spiketimes) =
    calc_STA(vrec(sim), spiketimes, sim.Δt, winsize)

function conntest(spiketimes, sim)
    sta = calcSTA(sim, spiketimes)
    shufs = [
        calcSTA(sim, shuffle_ISIs(spiketimes))
        for _ in 1:100
    ]
    test_conn(ptp_test, sta, shufs)
end;

# +
# @code_warntype calc_STA(vrec(s), st1, s.Δt, winsize)
# all good
# -

conntest_all(simruns[1])

conntest_all(simruns[3]);

# ✔

# ..but, it takes 25 seconds for simrun 3, i.e. for..

length(simruns[3].input.inputs)

# ..inputs.
#
# so extrapolating, the last one would take

25seconds * 6500/100 / minutes

# Almost half an hour.
#
# So this is why we cached and parallel-processed the STA calculation

# ### Cache STA calc

cached()

nbname = "2022-10-24__Nto1_with_fixed_lognormal_inputs"
cachekey(N) = "$(nbname)__N=$N";
cachekey(Ns[end])

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
unpakk(simrun) = (; simrun.input.inputs, simrun.sim)

out = calc_all_STAz(simruns[1])
print(Base.summary(out))

# + tags=[]
calc_all_cached(i) = cached(calc_all_STAz, [simruns[i]], key=cachekey(Ns[i]))

out = []
for i in eachindex(simruns)
    push!(out, calc_all_cached(i))
end;
# -

path = raw"C:\Users\tfiers\.phdcache\calc_all_STAz\2022-10-24__Nto1_with_fixed_lognormal_inputs__N=6500.jld2"
stat(path).size / GB

# (Yeah, shuffle test not great here)

# ### Conntest based on STA cache

[test_conn(ptp_test, sta, shufs) for (sta,shufs) in out[1]]

# ✔, same as above

# ## Two-stage conntest, ptp-then-correlation

# ..wait, that assumes we can even find some true connections with ptp.

# So let's try that.

# +
# We need.. a column with `conntype`, the real type.
# -

i = last(eachindex(simruns))

sim, inp = simruns[i];

Nₑ = inp.Nₑ

N = Ns[i]

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

conntestresults(1)
# -

ctr = conntestresults(6)

# ## Eval

# +
pm = perfmeasures(ctr)

perftable(ctr)
# -

# So 3 to 4% of connections detected.\
# α = FPR = 5%.\
# So, alas

# ## Analyse

# Did the high firing inputs fare better?

sim,inp = simruns[6]
inp.firing_rates;

# For starters, are the input firing rates the actual firing rates:

spikerate_(spiketimes) = length(spiketimes) / sim_duration;

using Sciplotlib: plot

stipulated_firing_rates = inp.firing_rates
real_firing_rates = spikerate_.(spiketimes.(inp.inputs))
plot(stipulated_firing_rates, real_firing_rates);

# Ok, check

fr, nid = findmax(real_firing_rates)

# (It's an inh one)

plotSTA(nid) = plot(calcSTA(sim, spiketimes(inp.inputs[nid])) / mV);
plotSTA(nid);

fr, nid_exc = findmax(real_firing_rates[1:inp.Nₑ])

plotSTA(nid_exc);

# Alas alas.

# ## What about the second to last one, N = 1600

i = length(Ns) - 1

Ns[i]

sims = first.(simruns);
inps = last.(simruns);

# +
firing_rates(i) = spikerate_.(spiketimes.(inps[i].inputs))

fr,ni = findmax(firing_rates(5))
# -

plotSTA(i,ni) = plot(calcSTA(sims[i], spiketimes(inps[i].inputs[ni])) / mV);

plotSTA(i,ni);

# Ah, that's better!

ctr = conntestresults(5)
perftable(ctr)

# So here it's worth doing a two-pass test:

# ### Two-pass test (strict ptp, then correlation)

ctr_strict = conntestresults(5, α=1/100)
perftable(ctr_strict)

ids = findall(ctr_strict.predtype .== :exc)
length(ids)

# Hm although: of the 120 connections predicted 'exc', more than half are actually inh

# Let's see what an average STA gives anyway

# +
sim,inp = simruns[5]
STAs_predicted_exc = [calcSTA(sim, spiketimes(inp.inputs[i])) for i in ids];

template = mean(STAs_predicted_exc)

plot(template/mV);
# -

# Hm, interesting. Not the previously known STA shape.

# [not furhter explored why]

# Now to correlation-conntest with this

# +
ctr2 = conntestresults(5, corr_test $ (; template), α = 0.05)

perftable(ctr2)
# -

# Lol it's worse.

# Ok, that's cause there's more inh in template.\
# (That's why STA lookd different)

# So let's use inh as template

ids_inh = findall(ctr_strict.predtype .== :inh)
length(ids_inh)

# +
STAs_predicted_inh = [calcSTA(sim, spiketimes(inp.inputs[i])) for i in ids_inh];

plot(mean(STAs_predicted_inh)/mV)

template_inh = - mean(STAs_predicted_inh);  # Note the minus
# -

# That's more like it

# +
ctr3 = conntestresults(5, corr_test $ (; template=template_inh), α = 0.05)

perftable(ctr3)
# -

# Ok, not bad :)

# Comparing with prev results here: 
# https://tfiers.github.io/phd/nb/2022-04-28__interpolate_N_from_30_to_6000.html#plot-results
#
# At 1600 inputs, there TPRₑ was 5%  (here 34%)\
# and TPRᵢ was 21%   (here 82%)
#
# ofc that was with just ptp test.
# this is with the two phase test.

# Just the ptp here:

# TPRₑ 9%\
# TPRᵢ 36%
#
# so it _is_ a bit better, with the lognormal input firing

# ## Try two-pass test on N=6500 anyway

# But, as above, with the inh as template.

ctr6_strict = conntestresults(6, α=1/100)
perftable(ctr6_strict)

ids6_inh = findall(ctr6_strict.predtype .== :inh)
length(ids6_inh)

# +
sim,inp = simruns[6]

STAs6_predicted_inh = [calcSTA(sim, spiketimes(inp.inputs[i]))
                        for i in ids6_inh];

avg = mean(STAs6_predicted_inh)

plot(avg/mV)

template_inh6 = - avg;
# -

# Hm. Less convincing.
#
# (Let's try anyway)

# +
ctr6_2 = conntestresults(
    6, corr_test $ (; template=template_inh6), α = 0.05
)

perftable(ctr6_2)
# -

# Just ptp above (H2 'Eval') had
#
# Precision\
# 62%\
# 25%
#
# Sensitivity  3%  4%

# So, this is worse.
