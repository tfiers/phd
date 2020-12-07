"""
Integrate the ODE of the Izhikevich model neuron.

The real work happens in `_sim_izh()`.
"""
from dataclasses import asdict, dataclass
from functools import partial

import matplotlib.pyplot as plt
from numba import njit
from numpy import empty, ones, zeros

from .params import IzhikevichParams, cortical_RS
from .support.time_grid import TimeGrid
from .support.units import add_unit_support, mV, ms, pA
from .support.signal import Signal


@dataclass
class SimResult:
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
    calc_with_units: bool = False,
) -> SimResult:

    if g_syn is None:
        g_syn = zeros(time_grid.N) * pA
    if I_e is None:
        I_e = zeros(time_grid.N) * pA

    V_m = empty(time_grid.N) * mV
    u = empty(time_grid.N) * pA
    I_syn = empty(time_grid.N) * pA

    if calc_with_units:
        f = _sim_izh
    else:  # Compile with Numba
        f = add_unit_support(njit(_sim_izh, cache=True))

    f(V_m, u, I_syn, g_syn, I_e, time_grid.dt, **asdict(params))

    return SimResult(V_m, u, I_syn)


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
    tg = TimeGrid(T=200 * ms, dt=0.5 * ms)
    constant_input = ones(tg.N) * 80 * pA
    f = partial(simulate_izh_neuron, tg, cortical_RS, I_e=constant_input, g_syn=None)
    sim_with_units = f(calc_with_units=True)
    sim_fast = f(calc_with_units=False)
    # assert_allclose_units(sim_fast.V_m, sim_with_units.V_m)
    # assert_allclose_units(sim_fast.u, sim_with_units.u)
    # assert_allclose_units(sim_fast.I_syn, sim_with_units.I_syn)
    # print("Simulations with and without units yield equal results.")
    plt.plot(tg.t / ms, sim_fast.V_m)
    plt.xlabel("Time (ms)")
