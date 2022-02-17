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
@alias CArray = ComponentArray;

save(fname) = savefig(fname, subdir="methods");

# ## Parameters

sim_duration = 0.11 * seconds
Δt = 0.1 * ms;  # size of first step only, when solver is adaptive

# ### Input spikers

N_unconn = 100
N_exc    = 5200
N_inh    = N_exc ÷ 4

N_unconn = 1
N_exc    = 8
N_inh    = N_exc ÷ 4

N_conn = N_inh + N_exc

N = N_conn + N_unconn

input_spike_rate = LogNormal_with_mean(4Hz, √0.6)  # See the previous notebook

# + [markdown] heading_collapsed=true
# ### Synapses

# + [markdown] hidden=true
# Reversal potential at excitatory and inhibitory synapses,  
# as in the report [`2021-11-11__synaptic_conductance_ratio.pdf`](https://github.com/tfiers/phd-thesis/blob/main/reports/2021-11-11__synaptic_conductance_ratio.pdf):

# + hidden=true
v_exc =   0 * mV
v_inh = -65 * mV;

# + [markdown] hidden=true
# Exponential decay time constant of synaptic conductance `g`, $τ_{s}$ (`s` for "synaptic"):

# + hidden=true
τ_s =   7 * ms;

# + [markdown] hidden=true
# Synaptic conductances at `t = 0`:

# + hidden=true
g0 = 0 * nS;

# + [markdown] heading_collapsed=true
# ### Izhikevich neuron

# + [markdown] hidden=true
# Membrane potential `v` and adaptation variable `u` at `t = 0`:

# + hidden=true
v0    = -80 * mV
u0    =   0 * pA;

# + [markdown] hidden=true
# Parameters for a cortical regular spiking neuron:

# + hidden=true
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

cortical_RS = IzhikevichParams();
# -

# ## IDs

# Simple here for the N-to-1 case: only input 'neurons' get an ID, and there is only one synapse for every (connected) neuron.

# ### Neuron IDs

neuron_ids = CArray(exc = 1:N_exc, inh = 1:N_inh, unconn = 1:N_unconn)

only(getaxes(neuron_ids))

resetrng!(797)
showsome(labels(neuron_ids))

# i.e. a neuron's **global** ID = its index into the [ComponentVector](https://github.com/jonniedie/ComponentArrays.jl) "`neuron_ids`".

# + [markdown] heading_collapsed=true
# ### Synapse IDs

# + hidden=true
synapse_ids = CArray(exc = 1:N_exc, inh = 1:N_inh)
# -

# ## Inputs

# Generate firing rates $λ$ by sampling from the input spike rate distribution.

λ = rand(input_spike_rate, N)
showsome(λ)

# Alternative Exp parametrisation: scale $β$ = 1 / rate.

β = 1 ./ λ
ISI_distributions = Exponential.(β);
#   This uses julia's broadcasting `.` syntax: make an `Exponential` distribution for every value in the β vector

# Create $E_i$: for each neuron, the reversal potential at its downstream synapses.

E = CArray(exc=fill(v_exc, N_exc), inh=fill(v_inh, N_inh))

# ## Sim

neuron_ids

using DataStructures: PriorityQueue

# +
first_spiketimes = rand.(ISI_distributions)

pq = PriorityQueue{Int, Float64}()
for (neuron_ID, t) in enumerate(first_spiketimes)
    enqueue!(pq, neuron_ID => t)
end

next_spike_time, neuron_ID = dequeue_pair!(pq)

# t = 0s
# while t < sim_duration
#     input_neuron, t = dequeue_pair!(pq)  # earliest spike
#     new_ISI = rand(ISI_distributions[input_neuron])
#     enqueue!(pq, input_neuron => t + new_ISI)
# end
# -

using OrdinaryDiffEq

# +
function f(D, vars, params, _t)
    @unpack v, u, g = vars
    @unpack C, k, b, v_r, v_t, v_peak, c, a, d = params
    I_s = sum(g .* (v .- E))
        # Membrane current is by convention positive if positive charges are flowing out of the cell.
        # For v = -80 mV and v_s = 0 mV, we get negative I_s, i.e. charges flowing in ✔.
    D.v = (k * (v - v_r) * (v - v_t) - u - I_s) / C
    D.u = a * (b * (v - v_r) - u)
    D.g = -g ./ τs
    return nothing
end

# distance_to_thr_crossing(vars, _t, integrator) = integrator.p.v_peak - vars.v
distance_to_thr_crossing(vars, _t, integrator) = v0 - vars.v
    # Function that is zero at desired event.

function on_thr_crossing(integrator)
    vars, params = integrator.u, integrator.p
    vars.v = v0
#     vars.v = params.c
#     vars.u += params.d
end

cb = ContinuousCallback(distance_to_thr_crossing, on_thr_crossing)

x0 = ComponentArray{Float64}(v = v0, u = u0, g = fill(g0, N_conn))  # Note eltype cast to float.
prob = ODEProblem(f, x0, float(sim_duration), cortical_RS)  # Time must also be float.
@time sol = solve(
    prob,
    Tsit5();          # The default solver. A Runge-Kutta method. Tsitouras 2011.
    dt = Δt,          # Size of first step.
    adaptive = true,  # Take larger steps when output is steady.
    reltol = 1e-8,    # default: 1e-2
    abstol = 1e-8,    # default: 1e-6
    callback = cb,
);
# -

# Tolerances from https://diffeq.sciml.ai/stable/tutorials/ode_example/#Choosing-a-Solver-Algorithm and experimentation:  
# Lower for either gives incorrect oscillations in steady state (non-todo: show this in a separate nb).

plot(sol.t/ms, sol[1,:]/mV);


