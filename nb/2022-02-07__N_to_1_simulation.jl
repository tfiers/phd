# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.7
#   kernelspec:
#     display_name: Julia 1.7.0
#     language: julia
#     name: julia-1.7
# ---

# # 2022-02-07 • N-to-1 simulation

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

dt    = 0.1 * ms;

# Minimum and maximum step sizes

dtmax = 0.5  * ms  # solution unstable if not set
dtmin = 0.01 * ms;  # don't spend too much time finding thr crossing or spike arrival

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

input_neurons = idvec(conn = idvec(exc = N_exc, inh = N_inh), unconn = N_unconn)

synapses = idvec(exc = N_exc, inh = N_inh)

simulated_vars = idvec(v = nothing, u = nothing, g = synapses)

# Example usage of these objects:

# Pick some global input neuron ID

n = N_exc + 2

# We can index globally, or locally: we want the second connected inhibitory neuron

input_neurons[n], input_neurons.conn.inh[2]

# Some introspection, useful for printing & plotting:

labels(input_neurons)[n]

# ## Connections

# +
postsynapses = Dict{Int, Vector{Int}}()  # input_neuron_ID => [synapse_IDs...]

for (n, s) in zip(input_neurons.conn, synapses)
    postsynapses[n] = [s]
end
for n in input_neurons.unconn
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

# Initial conditions

vars_t0 = similar(simulated_vars, Float64)
vars_t0.v = v_t0
vars_t0.u = u_t0
vars_t0.g .= g_t0;

# Maximum error

abstol = similar(simulated_vars, Float64)
abstol.v = abstol_v
abstol.u = abstol_u
abstol.g .= abstol_g
abstol = abstol .* tol_correction;

# ## ISI distributions

# Generate firing rates $λ$ by sampling from the input spike rate distribution.

λ = similar(input_neurons, Float64)
λ .= rand(input_spike_rate, length(λ));
# showsome(λ)

# `Distributions.jl` uses an alternative `Exp` parametrization, namely scale $β$ = 1 / rate.

β = 1 ./ λ;

ISI_distributions = similar(input_neurons, Exponential{Float64})
ISI_distributions .= Exponential.(β);

# ## Initialize spiking

# Generate the first spike time for every input neuron by sampling once from its ISI distribution.

first_spike_times = rand.(ISI_distributions);

# Sort these initial spike times by building a priority queue.

# +
upcoming_input_spikes = PriorityQueue{Int, Float64}()

for (neuron, first_spike_time) in enumerate(first_spike_times)
    enqueue!(upcoming_input_spikes, neuron => first_spike_time)
end
# -

# ## Parameter object

# Encapsulate all 'parameters' used in the differential equation function
# and the event callback functions in one `NamedTuple`,
# which is passed through to these functions by DiffEq.jl.
#
# This is so that we don't need to read these variables
# from the global scope (closure), which slows type inference i.e. compilation time.
#
# 'parameters' in quotes, cause some values are mutated.

params = (;
    E, Δg, τ_s,
    izh = cortical_RS,
    postsynapses,
    ISI_distributions,
    upcoming_input_spikes,
);

# ## Differential equations

# The derivative functions that define the differential equations.
# Note that discontinuities are defined in the next section.

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
# - Don't use `I_s = sum(g .* (v .- E))`, which allocates a new array. Rather, we use an accumulating loop.
# - `D.g .= …`: elementwise assignment; instead of overwriting `D.g` with a new array that needs to be allocated.
# - Parameters via function argument, and not closure of global variables: to speed up type inference (apparently).

# About the sign of the synaptic current `I_s`:
# membrane current is by convention positive
# if positive charges are flowing _out_ of the cell.
#
# For *e.g.* `v = -80 mV` and `Ei = 0 mV` (*i.e.* an excitatory synapse),
# we get negative `I_si` (namely `gi * -80 mV`), *i.e.* positive charges flowing in ✔.

# ## Events

"""
An `Event` encapsulates two functions that determine when and
how to introduce discontinuities in the differential equations:

- `distance` returns some distance to the next event.
   An event occurs when this distance hits zero.
- `on_event!` is called at each event and may modify
   the simulated variables and the parameter object.

Both functions take the parameters `(vars, params, t)`: the simulated
variables, the parameter object, and the current simulation time.
"""
struct Event
    distance
    on_event!
end;

# Input spike generation (== arrival, because no transmission delay):

# +
function time_to_next_input_spike(vars, params, t)
    _, next_input_spike_time = peek(params.upcoming_input_spikes)
        # `peek(pq)` simply returns `pq.xs[1]`; i.e. it's fast.
    return t - next_input_spike_time
end

function on_input_spike!(vars, params, t)
    # Process the neuron that just fired.
    # Start by removing it from the queue.
    fired_neuron = dequeue!(params.upcoming_input_spikes)

    # Generate a new spike time, and add it to the queue.
    new_spike_time = t + rand(params.ISI_distributions[fired_neuron])
    enqueue!(params.upcoming_input_spikes, fired_neuron => new_spike_time)

    # Update the downstream synapses
    # (number of these synapses in the N-to-1 case: 0 or 1).
    for synapse in params.postsynapses[fired_neuron]
        vars.g[synapse] += params.Δg[synapse]
    end

end

input_spike = Event(time_to_next_input_spike, on_input_spike!);
# -

# Spiking threshold crossing of Izhikevich neuron:

# +
distance_to_spiking_threshold(vars, params, _) = vars.v - params.izh.v_peak

function on_spiking_threshold_crossing!(vars, params, _)
    # The discontinuous LIF/Izhikevich/AdEx update
    vars.v = params.izh.c
    vars.u += params.izh.d
end

spiking_threshold_crossing = Event(distance_to_spiking_threshold, on_spiking_threshold_crossing!);
# -

events = [input_spike, spiking_threshold_crossing];

# ## diffeq.jl API

# Set-up problem and solution in DifferentialEquations.jl's API.

@withfeedback using OrdinaryDiffEq

prob = ODEProblem(f, vars_t0, float(sim_duration), params)
    # Duration must be float, so that `t` variable is float.

# +
function condition(distance, vars, t, integrator)
    for (i, event) in enumerate(events)
        distance[i] = event.distance(vars, integrator.p, t)
    end
end

function affect!(integrator, i)
    events[i].on_event!(integrator.u, integrator.p, integrator.t)
end

callback = VectorContinuousCallback(condition, affect!, length(events));
# -

# The default and recommended solver. A Runge-Kutta method. Refers to Tsitouras 2011.
# See http://www.peterstone.name/Maplepgs/Maple/nmthds/RKcoeff/Runge_Kutta_schemes/RK5/RKcoeff5n_1.pdf

solver = Tsit5()

# Don't save all the synaptic conductances, only save `v` and `u`.

save_idxs = [simulated_vars.v, simulated_vars.u];

# Log progress (only relevant in REPL; not visible in nb)

progress = true;

solve_() = solve(
    prob, solver;
    callback, save_idxs, progress,
    adaptive, dt, dtmax, dtmin, abstol, reltol,
);

# ## Solve

sol = @time solve_();

# ## Plot

@withfeedback import PyPlot
using Sciplotlib

""" tzoom = [200ms, 600ms] e.g. """
function Sciplotlib.plot(sol::ODESolution; tzoom = nothing)
    isnothing(tzoom) && (tzoom = sol.t[[1,end]])
    izoom = first(tzoom) .< sol.t .< last(tzoom)
    plot(
        sol.t[izoom] / ms,
        sol[1,izoom] / mV,
        clip_on = false,
        marker = ".", ms = 1.2, lw = 0.4,
        #  xlim = tzoom,  # haha lolwut, adding this causes fig to no longer display.
    )
end;

plot(sol);
