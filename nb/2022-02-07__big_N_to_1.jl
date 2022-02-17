# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.6
#   kernelspec:
#     display_name: Julia 1.7.1
#     language: julia
#     name: julia-1.7
# ---

# # 2022-02-07 • Big-N-to-1 simulation

# +
# Pkg.resolve()
# -

include("nb_init.jl")

using Parameters, ComponentArrays
@alias CVec = ComponentVector;

save(fname) = savefig(fname, subdir="methods");

# ## Parameters

sim_duration = 0.11 * seconds
Δt = 0.1 * ms;  # size of first step only, when solver is adaptive

# ### Input spikers

# +
# N_unconn = 100
# N_exc    = 5200
# N_inh    = N_exc ÷ 4

N_unconn = 1
N_exc    = 8
N_inh    = N_exc ÷ 4
# -

N_conn = N_inh + N_exc

N = N_conn + N_unconn

input_spike_rate = LogNormal_with_mean(4Hz, √0.6)  # See the previous notebook

# ### Synapses

# Reversal potential at excitatory and inhibitory synapses,  
# as in the report [`2021-11-11__synaptic_conductance_ratio.pdf`](https://github.com/tfiers/phd-thesis/blob/main/reports/2021-11-11__synaptic_conductance_ratio.pdf):

v_exc =   0 * mV
v_inh = -65 * mV;

# Synaptic conductances `g` at `t = 0`:

g0 = 0 * nS;

# Exponential decay time constant of synaptic conductance, $τ_{s}$ (`s` for "synaptic"):

τ_s = 7 * ms;

# Increase in synaptic conductance on a presynaptic spike.

Δg = 3 * nS;

# ### Izhikevich neuron

# Membrane potential `v` and adaptation variable `u` at `t = 0`:

v0    = -80 * mV
u0    =   0 * pA;

# Parameters for a cortical regular spiking neuron:

# +
@with_kw struct IzhikevichParams
    C      = 100 * pF
    k      = 0.7 * (nS/mV)
    b      = -2 * nS
    v_r    = -60 * mV
    v_t    = -40 * mV
    v_peak =  35 * mV
    c      = -50 * mV       # reset voltage.
    a      = 0.03 / ms      # 1 / time constant of `u`
    d      = 100 * pA       # `u` increase on spike. Free parameter.
end

cortical_RS = IzhikevichParams()

# Fix these params globally for now.
@unpack C, k, b, v_r, v_t, v_peak, c, a, d = cortical_RS;
# -

# ## Neurons & synapses

# Simple here for the N-to-1 case: only input 'neurons' get an ID, and there is only one synapse for every (connected) neuron.

@alias NeuronID = Int
@alias SynapseID = Int;

"""Given group names and numbers, build a CVec with these group names and a unique ID for each element."""
function ID_CVec(; kw...)
    transform(val::Number) = fill(-1, val)
    transform(val::CVec) = val  # allow nested ID_CVecs.
    cv = CVec(; [key => transform(val) for (key, val) in kw]...)
    cv[:] = 1:length(cv)
    return cv
end;

# ### Neuron IDs

neuron_ids = ID_CVec(conn = ID_CVec(exc = N_exc, inh = N_inh), unconn = N_unconn)

id = N_exc + 1
neuron_ids[id], labels(neuron_ids)[id]

# ### Synapse IDs

synapse_ids = ID_CVec(exc = N_exc, inh = N_inh)

# ### Connections

# +
using DataStructures: OrderedDict

postsynapses = OrderedDict{NeuronID, Vector{SynapseID}}()

for (n,s) in zip(neuron_ids.conn, synapse_ids)
    postsynapses[n] = [s]
end

postsynapses
# -

# ## Sim

# ### ISI distributions

# Generate firing rates $λ$ by sampling from the input spike rate distribution.

λ = rand(input_spike_rate, N)
showsome(λ)

# `Distributions.jl` uses alternative Exp parametrisation with scale $β$ = 1 / rate.

β = 1 ./ λ
ISI_distributions = Exponential.(β);
#   This uses julia's broadcasting `.` syntax: make an `Exponential` distribution for every value in the β vector

# ### Init spike times

# Generate the first spike time for every input neuron by sampling once from its ISI distribution.

first_spiketime_per_neuron = rand.(ISI_distributions);

# Sort these initial spike times by building a priority queue.

using DataStructures: PriorityQueue

next_input_spikes = PriorityQueue{NeuronID, Float64}()
for (neuron_ID, t) in enumerate(first_spiketime_per_neuron)
    enqueue!(next_input_spikes, neuron_ID => t)
end

# Pop off the top of the heap to find the first spiker.

first_input_spike_time, first_input_spike_neuron = dequeue_pair!(next_input_spikes)

# ### Differential equations 

using OrdinaryDiffEq

# The derivative function that defines the continuous differential equations:

function f(D, vars, _, _)
    @unpack v, u, g = vars
    I_s = sum(g .* (v .- E))  # Sum synaptic currents.
        # Membrane current is by convention positive if positive charges are flowing out of the cell.
        # For e.g. v = -80 mV and E = 0 mV, we get negative I_s, i.e. charges flowing in ✔.
    D.v = (k * (v - v_r) * (v - v_t) - u - I_s) / C
    D.u = a * (b * (v - v_r) - u)
    D.g = -g ./ τs
    return nothing
end;

# `E` is simply a vector with for each neuron the reversal potential at its downstream synapses.

E = CVec(exc = fill(v_exc, N_exc), inh = fill(v_inh, N_inh))

# ### Events

# +
events = (
    thr_crossing          = 1,
    input_spike_generated = 2,
)

function update_distance_to_next_event(distance, vars, t, integrator)
    v = vars.v
    p = integrator.p  # params
    distance[events.thr_crossing]          = v - v_peak
    distance[events.input_spike_generated] = t - p.next_input_spike_time
end

function on_event(integrator, event)
    vars = integrator.u
    @unpack p, t = integrator  # params, time
    
    if event == events.thr_crossing
        # The discontinuous LIF/Izhikevich/AdEx update
        vars.v = c
        vars.u += d
        
    elseif event == events.spike_generated
        # Generate a new spike for the just fired input neuron.
        fired_neuron = p.next_input_spike_neuron
        new_ISI = rand(ISI_distributions[fired_neuron])
        enqueue!(next_input_spikes, fired_neuron => t + new_ISI)
        # Update the downstream synapses (one or zero in this case).
        # Also note: no tx delay.
        vars.g[postsynapses[fired_neuron]] .+= Δg
        # Update params: find next spike.
        p.next_input_spike_neuron, p.next_input_spike_time = dequeue_pair!(next_input_spikes)
    end
end
# -

# ### Run simulation

# Bring it all together (initial conditions, derivatives function, events) and solve.

vars_t0 = CVec{Float64}(  # Note the cast to float, so that vars are float during sim.
    v = v0, 
    u = u0, 
    g = fill(g0, N_conn),
)

params = CVec(
    next_input_spike_time   = first_input_spike_time,
    next_input_spike_neuron = first_input_spike_neuron,
)

# +
prob = ODEProblem(f, vars_t0, float(sim_duration), params)
    # Duration must be float too, so that `t` variable is float.

@time sol = solve(
    prob,
    Tsit5();          # The default and recommended solver. A Runge-Kutta method. Tsitouras 2011.
    dt = Δt,          # Size of first step.
    adaptive = true,  # Take larger steps when output is steady.
    reltol = 1e-8,    # default: 1e-2
    abstol = 1e-8,    # default: 1e-6
    callback = VectorContinuousCallback(update_distance_to_next_event, on_event, length(events)),
);
# -

# Tolerances are from https://diffeq.sciml.ai/stable/tutorials/ode_example/#Choosing-a-Solver-Algorithm and experimentation:  
# Lower for either gives incorrect oscillations in steady state (non-todo: show this in a separate nb).

plot(sol.t/ms, sol[1,:]/mV);


