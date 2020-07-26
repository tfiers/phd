"""
Integrate the ODE of the Izhikevich model neuron.

The real work happens in `_sim()`.

The other code strips units from quantities (for speed during calculation), adds them
back after, and tests the results.
"""
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from time import time
from typing import Optional

import matplotlib.pyplot as plt
from numba import jit
from numpy import empty, ones, zeros
from toolz import valmap
from unyt import assert_allclose_units, unyt_array
from voltage_to_wiring_sim.neuron_params import cortical_RS

from .neuron_params import IzhikevichParams
from .time_grid import TimeGrid, short_time_grid
from .units import mV, pA, strip_units, QuantityCollection


@dataclass
class SimResult(QuantityCollection):
    V_m: unyt_array
    u: unyt_array
    I_syn: unyt_array

    def __post_init__(self):
        self.V_m.name = "Membrane voltage"
        self.V_m.convert_to_units("mV")

        self.u.name = "Slow current 'u'"
        self.u.convert_to_units("pA")

        self.I_syn.name = "Synaptic current"
        self.I_syn.convert_to_units("pA")


def simulate_izh_neuron(
    time_grid: TimeGrid,
    params: IzhikevichParams,
    g_syn: unyt_array = None,
    I_e: unyt_array = None,
    num_test_iterations: Optional[int] = None,
) -> SimResult:

    if g_syn is None:
        g_syn = zeros(time_grid.N) * pA

    if I_e is None:
        I_e = zeros(time_grid.N) * pA

    def output_arrays(num_timesteps):
        return dict(
            v=empty(num_timesteps) * mV,
            u=empty(num_timesteps) * pA,
            I_syn=empty(num_timesteps) * pA,
        )

    # Create a keyword argument dictionary to pass to `_sim()`. (Numba can't yet handle
    # data classes, alas; so we have to unpack them as separate arguments).
    sim_args = dict(dt=time_grid.dt, g_syn=g_syn, I_e=I_e, **asdict(params))

    if num_test_iterations is not None:
        # Run the simulation for a limited number of iterations, but with all units kept
        # in place.
        test_sim_args = dict(
            **sim_args, **output_arrays(num_timesteps=num_test_iterations)
        )
        with report_duration("test simulation with units"):
            V_m_test, u_test, I_syn_test = _sim(**test_sim_args)

    # Run the simulation for the entire time grid, but with units stripped off.
    fast_sim_args = valmap(
        strip_units, dict(**sim_args, **output_arrays(num_timesteps=time_grid.N))
    )
    V_m, u, I_syn = _sim_fast(**fast_sim_args)
    # We gave the simulation base SI units, therefore the results are in base units too.
    result = SimResult(
        V_m=unyt_array(V_m, units="V"),
        u=unyt_array(u, units="A"),
        I_syn=unyt_array(I_syn, units="A"),
    )

    if num_test_iterations is not None:
        # Test whether the fast, unitless simulation gives the same results as the
        # simulation with units.
        assert_allclose_units(V_m_test, result.V_m[:num_test_iterations])
        assert_allclose_units(u_test, result.u[:num_test_iterations])
        assert_allclose_units(I_syn_test, result.I_syn[:num_test_iterations])

    return result


@contextmanager
def report_duration(action_description: str):
    print("Running", action_description, end=" … ")
    t0 = time()
    yield
    duration = time() - t0
    print(f"✔ ({duration:.2g} s)")


def test():
    constant_electrode_current = ones(short_time_grid.N) * 60 * pA
    sim = simulate_izh_neuron(
        short_time_grid,
        cortical_RS,
        g_syn=None,
        I_e=constant_electrode_current,
        num_test_iterations=short_time_grid.N,
    )
    plt.plot(short_time_grid.t, sim.V_m)


# Pure Python/Numpy function that can be compiled to compact machine code by Numba,
# without any overhead due to generic Python object processing.
def _sim(v, u, I_syn, g_syn, I_e, dt, v_r, v_syn, k, v_t, C, a, b, v_peak, c, d):
    """
    v, u, I_syn:  empty arrays of length N, that will be filled during simulation, and
                  returned.
    g_syn, I_e: input arrays of length N.
    dt:           timestep (scalar).
    [other args]: scalars; see IzhikevichParams.
    """
    # fmt: off
    v[0] = v_r
    u[0] = 0
    calc_I_syn = lambda g_syn, v, v_syn: g_syn * (v - v_syn)
    I_syn[0] = calc_I_syn(g_syn[0], v[0], v_syn)
    for i in range(len(v) - 1):
        dv_dt = (k * (v[i] - v_r) * (v[i] - v_t) - u[i] + I_e[i]) / C
        du_dt = a * (b * (v[i] - v_r) - u[i])
        # First order ('Euler') ODE integration.
        v[i+1] = v[i] + dt * dv_dt
        u[i+1] = u[i] + dt * du_dt
        I_syn[i+1] = calc_I_syn(g_syn[i+1], v[i+1], v_syn)
        if v[i+1] >= v_peak:
            v[i] = v_peak
            v[i+1] = c
            u[i+1] = u[i+1] + d
    return v, u, I_syn
    # fmt: on


_sim_fast = jit(_sim,)
