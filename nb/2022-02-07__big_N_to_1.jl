# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.10.0
#   kernelspec:
#     display_name: Julia 1.7.0
#     language: julia
#     name: julia-1.7
# ---

# # 2022-02-07 • Big-N-to-1 simulation

# ## Setup

# +
# Pkg.resolve()
# -

include("nb_init.jl")

using Parameters, ComponentArrays
@alias CVec = ComponentVector;

# ## Parameters

# ### Simulation duration

sim_duration = 1.2 * seconds;

# ### Input spike trains

N_unconn = 100
N_exc    = 800
# N_exc    = 5200
N_inh    = N_exc ÷ 4

N_conn = N_inh + N_exc

N = N_conn + N_unconn

input_spike_rate = LogNormal_with_mean(4Hz, √0.6)  # See the previous notebook

# ### Synapses

# Reversal potential at excitatory and inhibitory synapses,
# as in the report [`2021-11-11__synaptic_conductance_ratio.pdf`](https://github.com/tfiers/phd-thesis/blob/main/reports/2021-11-11__synaptic_conductance_ratio.pdf):

E_exc =   0 * mV
E_inh = -65 * mV;

# Synaptic conductances `g` at `t = 0`

g_t0 = 0 * nS;

# Exponential decay time constant of synaptic conductance, $τ_{s}$ (`s` for "synaptic")

τ_s = 7 * ms;

# Increase in synaptic conductance on a presynaptic spike

Δg_exc = 0.1 * nS
Δg_inh = 0.4 * nS;

# ### Izhikevich neuron

# Initial membrane potential `v` and adaptation variable `u` values

v_t0  = -80 * mV
u_t0  =   0 * pA;

# Izhikevich's neuron model parameters for a cortical regular spiking neuron:

cortical_RS = CVec(
    C      = 100 * pF,
    k      = 0.7 * (nS/mV),  # steepness of dv/dt's parabola
    vr     = -60 * mV,
    vt     = -40 * mV,
    a      = 0.03 / ms,      # 1 / time constant of `u`
    b      = -2 * nS,        # how strongly `v` deviations from `vr` increase `u`.
    v_peak =  35 * mV,
    c      = -50 * mV,       # reset voltage.
    d      = 100 * pA,       # `u` increase on spike. Free parameter.
);

# ### Numerics

# Whether to use a fixed (`false`) or [adaptive](https://www.wikiwand.com/en/Adaptive_step_size) timestep (`true`).

adaptive = true;

# Timestep. If `adaptive`, size of first time step.

dt = 0.1 * ms;

# Error tolerances used for determining step size, if `adaptive`.
#
# The solver guarantees that the (estimated) difference between
# the numerical solution and the true solution at any time step
# is not larger than `abstol + reltol * |y|`
# (where `y` ≈ the numerical solution at that time step).

abstol_v = 0.1 * mV
abstol_u = 0.1 * pA
abstol_g = 0.01 * nS;

reltol = 1e-3;  # e.g. if true sol is -80 mV, then max error of 0.08 mV
reltol = 1;     # only use abstol

# From the manual: "These tolerances are local tolerances and thus are not global guarantees. However, a good rule of thumb is that the total solution accuracy is 1-2 digits less than the relative tolerances." [[1]](https://diffeq.sciml.ai/stable/basics/faq/#What-does-tolerance-mean-and-how-much-error-should-I-expect)

tol_correction = 0.1;

(abstol_v, abstol_u, abstol_g) .* tol_correction

# For comparison, the default tolerances for ODEs in DifferentialEquations.jl are
# - `reltol = 1e-2`
# - `abstol = 1e-6`.

# Minimum and maximum stepsizes

dtmax = 0.5 * ms;

# ## IDs

# Neuron, synapse & simulated variable IDs.

# IDs and connections are simple here for the N-to-1 case: only input 'neurons' get an ID, and there is only one synapse for every (connected) neuron.

# A utility function. See below for its usage.

# +
"""
    idvec(A = 4, B = 2, …)

Build a `ComponentVector` (CVec) with the given group names and
as many elements per group as specified. Each element gets a
unique ID within the CVec, which is also its index in the CVec.
I.e. the above call yields `CVec(A = [1,2,3,4], B = [5,6])`.
"""
function idvec(; kw...)
    cvec = CVec(; (name => _expand(val) for (name, val) in kw)...)
    cvec .= 1:length(cvec)
    return cvec
end;

temp = -1  # value does not matter; they get overwritten by UnitRange
_expand(val::Nothing) = temp
_expand(val::Integer) = fill(temp, val)
_expand(val::CVec)    = val              # allow nested idvecs
;
# -

neurons = idvec(conn = idvec(exc = N_exc, inh = N_inh), unconn = N_unconn)

synapses = idvec(exc = N_exc, inh = N_inh)

simulated_vars = idvec(v = nothing, u = nothing, g = synapses)

# Example usage of these objects:

# Pick some global neuron ID

neuron_ID = N_exc + 2

# We can index globally, or locally: we want the second inhibitory neuron

neurons[neuron_ID], neurons.conn.inh[2]

# Some introspection, useful for printing & plotting:

labels(neurons)[neuron_ID]

# ## Connections

# +
postsynapses = Dict{Int, Vector{Int}}()  # neuron_ID => [synapse_IDs...]

for (n, s) in zip(neurons.conn, synapses)
    postsynapses[n] = [s]
end
for n in neurons.unconn
    postsynapses[n] = []
end
# -

# ## Broadcast parameters

# A bunch of synaptic parameters are given as scalars, but pertain to multiple synapses at once.
# Here we broadcast these scalars to vectors

Δg = similar(synapses, Float64)
Δg.exc .= Δg_exc
Δg.inh .= Δg_inh;

E = similar(synapses, Float64)
E.exc .= E_exc
E.inh .= E_inh;

# Initial conditions:

vars_t0 = similar(simulated_vars, Float64)
vars_t0.v = v_t0
vars_t0.u = u_t0
vars_t0.g .= g_t0;

abstol = similar(simulated_vars, Float64)
abstol.v = abstol_v
abstol.u = abstol_u
abstol.g .= abstol_g
abstol = abstol .* tol_correction;

# ## Input spikes

# Generate firing rates $λ$ by sampling from the input spike rate distribution.

λ = rand(input_spike_rate, N)
showsome(λ)

# `Distributions.jl` uses an alternative `Exp` parametrization, namely scale $β$ = 1 / rate.

β = 1 ./ λ
ISI_distributions = Exponential.(β);
#   This uses julia's broadcasting `.` syntax: make an `Exponential` distribution for every value in the β vector

# Generate the first spike time for every input neuron by sampling once from its ISI distribution.

first_spike_times = rand.(ISI_distributions);

# Sort these initial spike times by building a priority queue.

# +
upcoming_input_spikes = PriorityQueue{Int, Float64}()

for (neuron, first_spike_time) in enumerate(first_spike_times)
    enqueue!(upcoming_input_spikes, neuron => first_spike_time)
end
# -

# Check the top of the heap to find the first spiker.

_, next_input_spike_time = peek(upcoming_input_spikes)
    # We `peek`, and not `dequeue_pair!`, to make this cell idempotent.

# ## Differential equations

params = CVec(; E, τ_s, izh = cortical_RS, next_input_spike_time);

# The derivative functions that defines the differential equations.
#
# Discontinuities are defined further down, under "Events".

function f(D, vars, params, _)
    @unpack v, u, g = vars
    @unpack izh, E, τ_s = params
    @unpack C, k, vr, vt, a, b = izh
    I_s = 0.0
    for (gi, Ei) in zip(g, E)
        I_s += gi * (v - Ei)
    end
    D.v = (k * (v - vr) * (v - vt) - u - I_s) / C
    D.u = a * (b * (v - vr) - u)
    D.g .= .-g ./ τ_s
    return nothing
end;

# Applied performance optimizations:
# - No `I_s = sum(g .* (v .- E))`, which allocates a new array. Rather: an accumulating loop.
# - `D.g .= …`: elementwise assignment (instead of overwriting `D.g` with a new array that needs to be allocated).
# - Parameters via function argument, and not closure global variables: to speed up type inference (apparently).

# For the synaptic currents $I_{s,i}$:
# membrane current is by convention positive
# if positive charges are flowing _out_ of the cell.
#
# For *e.g.* `v` = $-80$ mV and `Ei` = $0$ mV (an excitatory synapse),
# we get negative $I_s$, i.e. positive charges flowing in ✔.

# ## Events

# +
events = (
    thr_crossing           = 1,
    input_spike_generated  = 2,
)

function update_distance_to_next_event(distance, vars, t, integrator)
    v = vars.v
    p = integrator.p  # params
    distance[events.thr_crossing]          = v - p.izh.v_peak
    distance[events.input_spike_generated] = t - p.next_input_spike_time
end

function on_event(integrator, event)
    vars = integrator.u
    @unpack p, t = integrator  # params, time

    if event == events.thr_crossing
        # The discontinuous LIF/Izhikevich/AdEx update
        vars.v = p.izh.c
        vars.u += p.izh.d

    elseif event == events.input_spike_generated
        # Process the neuron that just fired. Start by removing it from the queue.
        fired_neuron = dequeue!(upcoming_input_spikes)
        # Generate a new spike time, and add it to the queue.
        new_spike_time = t + rand(ISI_distributions[fired_neuron])
        enqueue!(upcoming_input_spikes, fired_neuron => new_spike_time)
        # Update the downstream synapses (one or zero in the N-to-1 case).
        # Also note: no tx delay.
        for syn in postsynapses[fired_neuron]
            vars.g[syn] += Δg[syn]
        end
        # Update params: retrieve the next earliest spike.
        _, p.next_input_spike_time = peek(upcoming_input_spikes)
    end
end;
# -

# ## diffeq.jl API

# Set-up problem and solution in DifferentialEquations.jl's API.

@time using OrdinaryDiffEq

prob = ODEProblem(f, vars_t0, float(sim_duration), params)
    # Duration must be float too, so that `t` variable is float.

callback = VectorContinuousCallback(update_distance_to_next_event, on_event, length(events));

# The default and recommended solver. A Runge-Kutta method. Refers to Tsitouras 2011.
# See http://www.peterstone.name/Maplepgs/Maple/nmthds/RKcoeff/Runge_Kutta_schemes/RK5/RKcoeff5n_1.pdf

solver = Tsit5()

# Don't save all the synaptic conductances, only save `v` and `u`.

save_idxs = [simulated_vars.v, simulated_vars.u];

solve_() = solve(prob, solver; adaptive, dt, dtmax, abstol, reltol, callback);

# ## Solve

sol = @time solve_();

# start:   4.105806 seconds (5.08 M allocations: 944.455 MiB, 3.84% gc time, 58.86% compilation time)
#
# dtmin: 

@time using ProfileView

@profview @time solve();

# ## Plot

@time import PyPlot
using Sciplotlib

""" tzoom = [200ms, 600ms] e.g. """
function Sciplotlib.plot(sol::ODESolution; tzoom = nothing)
    isnothing(tzoom) && (tzoom = sol.t[[1,end]])
    izoom = first(tzoom) .< sol.t .< last(tzoom)
    plot(
        sol.t[izoom]/ms,
        sol[1,izoom]/mV,
        clip_on = false,
        marker = ".", ms = 1.2, lw = 0.4,
#         xlim = tzoom,  # haha lolwut, adding this causes fig to no longer display.
    )
end;

plot(sol);

plot(sol);




