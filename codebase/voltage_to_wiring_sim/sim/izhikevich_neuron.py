"""
Integrate the ODE of the Izhikevich model neuron.

The real work happens in `_sim_izh()`.
"""
from dataclasses import asdict, dataclass
from functools import partial

import matplotlib.pyplot as plt
from numpy import empty, ones, zeros

from .neuron_params import IzhikevichParams, cortical_RS
from ..support import Signal, TimeGrid, compile_to_machine_code
from ..support.units import mV, ms, pA


@dataclass
class IzhikevichOutput:
    V_m: Signal
    u: Signal
    I_syn: Signal

    # def __post_init__(self):
    #     self.V_m.name = "Membrane voltage"
    #     self.u.name = '"Slow current", u'
    #     self.I_syn.name = "Synaptic current"


def simulate_izh_neuron(
    time_grid: TimeGrid,
    params: IzhikevichParams,
    g_syn: Signal = None,
    I_e: Signal = None,
    pure_python = False,
) -> IzhikevichOutput:

    N = time_grid.N
    dt = time_grid.timestep

    if g_syn is None:
        g_syn = Signal(zeros(N) * pA, dt)
    if I_e is None:
        I_e = Signal(zeros(N) * pA, dt)

    V_m = Signal(empty(N) * mV, dt)
    u = Signal(empty(N) * pA, dt)
    I_syn = Signal(empty(N) * pA, dt)

    if pure_python:
        f = _sim_izh
    else:
        f = compile_to_machine_code(_sim_izh)

    f(V_m, u, I_syn, g_syn, I_e, dt, **asdict(params))

    return IzhikevichOutput(V_m, u, I_syn)


# Pure Python/NumPy function that can be compiled to compact machine code by Numba,
# without any overhead due to generic Python object processing.
# fmt: off
def _sim_izh(
    v, u, I_syn,  # Empty arrays of length N, filled in place during simulation.
    g_syn, I_e,  # Input arrays of length N.
    dt,  # Timestep (scalar).
    v_syn, v_r, k, v_t,
        C, a, b, v_peak, c, d  # Scalars. See `IzhikevichParams` dataclass.
):
    dv_dt = lambda i: (k * (v[i] - v_r) * (v[i] - v_t) - u[i] - I_syn[i] + I_e[i]) / C
    du_dt = lambda i: a * (b * (v[i] - v_r) - u[i])
    for i in range(len(v)):
        if i == 0:
            v[i] = v_r
            u[i] = 0
        else:
            v[i] = v[i-1] + dt * dv_dt(i-1)
            u[i] = u[i-1] + dt * du_dt(i-1)
            if v[i] >= v_peak:
                v[i-1] = v_peak
                v[i] = c
                u[i] += d
        I_syn[i] = g_syn[i] * (v[i] - v_syn)

# fmt: on


def test():
    tg = TimeGrid(duration=200 * ms, timestep=0.5 * ms)
    constant_input = ones(tg.N) * 80 * pA
    f = partial(simulate_izh_neuron, tg, cortical_RS, I_e=constant_input, g_syn=None)
    sim_with_units = f(pure_python=True)
    sim_fast = f(pure_python=False)
    # assert_allclose_units(sim_fast.V_m, sim_with_units.V_m)
    # assert_allclose_units(sim_fast.u, sim_with_units.u)
    # assert_allclose_units(sim_fast.I_syn, sim_with_units.I_syn)
    # print("Simulations with and without units yield equal results.")
    plt.plot(tg.time / ms, sim_fast.V_m)
    plt.xlabel("Time (ms)")
