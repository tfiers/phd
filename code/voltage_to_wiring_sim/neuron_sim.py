"""
Integrate the ODE of the Izhikevich model neuron.

The real work happens in `_sim()`.

The other code strips units from quantities (for speed during calculation), adds them
back after, and tests the results.
"""
from dataclasses import asdict, dataclass

import matplotlib.pyplot as plt
from numba import jit
from numpy import empty, ones, zeros
from toolz import valmap
from unyt import assert_allclose_units, unyt_array

from .neuron_params import IzhikevichParams, cortical_RS
from .time_grid import TimeGrid
from .units import QuantityCollection, mV, ms, pA, strip_units
from .util import report_duration


@dataclass
class SimResult(QuantityCollection):
    V_m: unyt_array
    u: unyt_array
    I_syn: unyt_array

    def __post_init__(self):
        self.V_m.name = "Membrane voltage"
        self.V_m.convert_to_units("mV")

        self.u.name = "Slow current, u"
        self.u.convert_to_units("pA")

        self.I_syn.name = "Synaptic current"
        self.I_syn.convert_to_units("pA")


def simulate_izh_neuron(
    time_grid: TimeGrid,
    params: IzhikevichParams,
    g_syn: unyt_array = None,
    I_e: unyt_array = None,
    fast: bool = True,
) -> SimResult:

    # Create a keyword argument dictionary to pass to `_sim()`. (Numba can't yet handle
    # data classes, alas; so we have to unpack them as separate arguments).
    sim_args = dict(
        v=empty(time_grid.N) * mV,
        u=empty(time_grid.N) * pA,
        I_syn=empty(time_grid.N) * pA,
        dt=time_grid.dt,
        g_syn=g_syn if g_syn is not None else zeros(time_grid.N) * pA,
        I_e=I_e if I_e is not None else zeros(time_grid.N) * pA,
        **asdict(params),
    )

    if fast:
        sim_args = valmap(strip_units, sim_args)
        V_m, u, I_syn = _sim_fast(**sim_args)
        # We gave the simulation base SI units, therefore the results are in base units
        # too.
        return SimResult(
            V_m=unyt_array(V_m, units="V"),
            u=unyt_array(u, units="A"),
            I_syn=unyt_array(I_syn, units="A"),
        )
    else:
        V_m, u, I_syn = _sim(**sim_args)
        return SimResult(V_m, u, I_syn)

    return result


def test():
    test_time_grid = TimeGrid(T=200 * ms, dt=0.1 * ms)
    # Constant electrode current
    constant_input = ones(test_time_grid.N) * 80 * pA
    with report_duration("Running simulation, without stripping units"):
        sim_with_units = simulate_izh_neuron(
            test_time_grid, cortical_RS, I_e=constant_input, g_syn=None, fast=False
        )
    with report_duration("Stripping units + running simulation"):
        sim_fast = simulate_izh_neuron(
            test_time_grid, cortical_RS, I_e=constant_input, g_syn=None, fast=True
        )
    # Require results to differ by no more than 1%
    rtol = 0.01
    assert_allclose_units(sim_fast.V_m, sim_with_units.V_m, rtol)
    assert_allclose_units(sim_fast.u, sim_with_units.u, rtol)
    assert_allclose_units(sim_fast.I_syn, sim_with_units.I_syn, rtol)
    plt.plot(test_time_grid.t, sim_fast.V_m)


# Pure Python/Numpy function that can be compiled to compact machine code by Numba,
# without any overhead due to generic Python object processing.
def _sim(v, u, I_syn, g_syn, I_e, dt, v_r, v_syn, k, v_t, C, a, b, v_peak, c, d):
    """
    v, u, I_syn:  empty arrays of length N, that will be filled during simulation, and
                  returned.
    g_syn, I_e:   input arrays of length N.
    dt:           timestep (scalar).
    [other args]: scalars; see IzhikevichParams.
    """
    # fmt: off
    v[0] = v_r
    u[0] = 0
    calc_I_syn = lambda g_syn, v, v_syn: g_syn * (v - v_syn)
    I_syn[0] = calc_I_syn(g_syn[0], v[0], v_syn)
    
    for i in range(len(v) - 1):
        dv_dt = (k * (v[i] - v_r) * (v[i] - v_t) - u[i] - I_syn[i] + I_e[i]) / C
        du_dt = a * (b * (v[i] - v_r) - u[i])
        # First order ('Euler') ODE integration.
        v[i+1] = v[i] + dt * dv_dt
        u[i+1] = u[i] + dt * du_dt
        if v[i+1] >= v_peak:
            v[i] = v_peak
            v[i+1] = c
            u[i+1] = u[i+1] + d
    
        I_syn[i+1] = calc_I_syn(g_syn[i+1], v[i+1], v_syn)
    
    return v, u, I_syn
    # fmt: on


_sim_fast = jit(_sim,)
