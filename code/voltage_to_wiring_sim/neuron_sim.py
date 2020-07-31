"""
Integrate the ODE of the Izhikevich model neuron.

The real work happens in `_sim()`.

The other code strips units from quantities (for speed during calculation), adds them
back after, and tests the results.
"""
from dataclasses import dataclass

import matplotlib.pyplot as plt
from numba import jit
from numpy import empty, ones, zeros
from unyt import assert_allclose_units

from .neuron_params import IzhikevichParams, cortical_RS
from .time_grid import TimeGrid
from .units import Array, QuantityCollection, inputs_as_raw_data, mV, ms, pA


@dataclass
class SimResult(QuantityCollection):
    V_m: Array
    u: Array
    I_syn: Array

    def __post_init__(self):
        self.V_m.name = "Membrane voltage"
        self.u.name = "Slow current, u"
        self.I_syn.name = "Synaptic current"


def simulate_izh_neuron(
    time_grid: TimeGrid,
    params: IzhikevichParams,
    g_syn: Array = None,
    I_e: Array = None,
    numba: bool = True,
) -> SimResult:

    if g_syn is None:
        g_syn = zeros(time_grid.N) * pA
    if I_e is None:
        I_e = zeros(time_grid.N) * pA

    V_m = empty(time_grid.N) * mV
    u = empty(time_grid.N) * pA
    I_syn = empty(time_grid.N) * pA

    # Create a keyword argument dictionary to pass to `_sim()`. (Numba can't yet handle
    # data classes, alas; so we have to unpack them as separate arguments).
    sim_args = dict(v=V_m, u=u, I_syn=I_syn, dt=time_grid.dt, g_syn=g_syn, I_e=I_e)
    sim_args.update(params.asdict())

    if numba:
        _sim_fast(**sim_args)
    else:
        _sim(**sim_args)

    return SimResult(V_m, u, I_syn)


# Pure Python/Numpy function that can be compiled to compact machine code by Numba,
# without any overhead due to generic Python object processing.
def _sim(v, u, I_syn, g_syn, I_e, dt, v_r, v_syn, k, v_t, C, a, b, v_peak, c, d):
    """
    v, u, I_syn:  empty arrays of length N, that will be filled (in place) during
                    simulation.
    g_syn, I_e:   input arrays of length N.
    dt:           timestep (scalar).
    [other args]: scalars; see IzhikevichParams.
    """
    # fmt: off
    v[0] = v_r
    u[0] = 0
    calc_I_syn = lambda i: g_syn[i] * (v[i] - v_syn)
    I_syn[0] = calc_I_syn(0)

    dv_dt = lambda i: (k * (v[i] - v_r) * (v[i] - v_t) - u[i] - I_syn[i] + I_e[i]) / C
    du_dt = lambda i: a * (b * (v[i] - v_r) - u[i])
    
    # ODE integration.
    for i in range(len(v) - 1):
        v[i+1] = v[i] + dt * dv_dt(i)
        u[i+1] = u[i] + dt * du_dt(i)
        if v[i+1] >= v_peak:
            v[i] = v_peak
            v[i+1] = c
            u[i+1] = u[i+1] + d
        I_syn[i+1] = calc_I_syn(i)

    # fmt: on


_sim_fast = inputs_as_raw_data(jit(_sim))


def test():
    test_time_grid = TimeGrid(T=200 * ms, dt=0.5 * ms)
    constant_input = ones(test_time_grid.N) * 80 * pA
    sim_with_units = simulate_izh_neuron(
        test_time_grid, cortical_RS, I_e=constant_input, g_syn=None, numba=False
    )
    sim_fast = simulate_izh_neuron(
        test_time_grid, cortical_RS, I_e=constant_input, g_syn=None, numba=True
    )
    assert_allclose_units(sim_fast.V_m, sim_with_units.V_m)
    assert_allclose_units(sim_fast.u, sim_with_units.u)
    assert_allclose_units(sim_fast.I_syn, sim_with_units.I_syn)
    print("Simulations with and without units yield equal results.")
    plt.plot(test_time_grid.t, sim_fast.V_m)
