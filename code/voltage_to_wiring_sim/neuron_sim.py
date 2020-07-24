from dataclasses import dataclass, asdict

import matplotlib.pyplot as plt
from numpy import zeros, empty, ones
from numba import jit
from unyt import unyt_array
from voltage_to_wiring_sim.neuron_params import cortical_RS

from .units import pA
from .neuron_params import IzhikevichParams
from .time_grid import time_grid
from .util import strip_input_units


@dataclass
class SimResult:
    V_m: unyt_array
    I_syn: unyt_array
    u: unyt_array


@strip_input_units
def izh_neuron(time_grid, params: IzhikevichParams, g_syn=None, I_e=None,) -> SimResult:
    """
    Input I and output v: arrays of length N.
    """

    if g_syn is None:
        g_syn = zeros(time_grid.N)

    if I_e is None:
        I_e = zeros(time_grid.N)

    # Pure Python/Numpy function that can be compiled to compact machine code by Numba,
    # without any overhead due to generic Python object processing.
    # (Numba can't yet handle data classes, alas; so we have to unpack them as
    # arguments).
    @jit
    def sim(N, dt, v_syn, k, v_r, v_t, C, a, b, v_peak, c, d):
        v = empty(N)
        u = empty(N)
        I_syn = empty(N)
        v[0] = v_r
        u[0] = 0
        for i in range(N - 1):
            I_syn[i] = g_syn[i] * (v[i] - v_syn)
            dv_dt = (k * (v[i] - v_r) * (v[i] - v_t) - u[i] - I_e[i]) / C
            du_dt = a * (b * (v[i] - v_r) - u[i])
            v[i + 1] = v[i] + dt * dv_dt
            u[i + 1] = u[i] + dt * du_dt
            if v[i + 1] >= v_peak:
                v[i] = v_peak
                v[i + 1] = c
                u[i + 1] = u[i + 1] + d
        return v, u, I_syn

    v, u, I_syn = sim(time_grid.N, time_grid.dt, **asdict(params))
    

    # We calculate in base SI units, therefore the results are too.
    return SimResult(
        V_m=unyt_array(v, units="V", name="Membrane voltage").in_units("mV"),
        u=unyt_array(u, units="A", name="Slow current 'u'").in_units("pA"),
        I_syn=unyt_array(I_syn, units="A", name="Synaptic current").in_units("pA"),
    )


def test():
    constant_electrode_current = ones(time_grid.N) * 100 * pA
    sim = izh_neuron(time_grid, cortical_RS, g_syn=None, I_e=constant_electrode_current)
    plt.plot(time_grid.t, sim.V_m)
