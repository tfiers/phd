from dataclasses import dataclass

import matplotlib.pyplot as plt
import numpy as np
from numba import jit
from unyt import pA, unyt_array

from .cortical_RS_neuron import izh_params
from .time_grid import time_grid
from .util import strip_input_units


@dataclass
class SimResult:
    V_m: unyt_array
    I_syn: unyt_array
    u: unyt_array


@strip_input_units
def izh_neuron(
    g_syn, I_e, time_grid, *, C, k, v_r, v_t, v_peak, a, b, c, d
) -> SimResult:
    """
    Input I and output v: arrays of length N.
    """
    v_t0 = v_r
    u_t0 = 0
    E_syn = 0

    N, dt = time_grid.N, time_grid.dt  # Numba can't yet handle data classes, alas.

    # Pure Python/Numpy function that can be compiled to compact machine code by Numba,
    # without any overhead due to generic Python object processing.
    @jit
    def sim():
        v = np.empty(N)
        u = np.empty(N)
        I_syn = np.empty(N)
        v[0] = v_t0
        u[0] = u_t0
        for i in range(N - 1):
            I_syn[i] = g_syn[i] * (v[i] - E_syn)
            dv_dt = (k * (v[i] - v_r) * (v[i] - v_t) - u[i] - I_e[i] + I_syn[i]) / C
            du_dt = a * (b * (v[i] - v_r) - u[i])
            v[i + 1] = v[i] + dt * dv_dt
            u[i + 1] = u[i] + dt * du_dt
            if v[i + 1] >= v_peak:
                v[i] = v_peak
                v[i + 1] = c
                u[i + 1] = u[i + 1] + d
        return v, u, I_syn

    v, u, I_syn = sim()
    # We calculate in base SI units, therefore the results are too.
    return SimResult(
        V_m=unyt_array(v, units="V", name="Membrane voltage").in_units("mV"),
        u=unyt_array(u, units="A", name="Slow current 'u'").in_units("pA"),
        I_syn=unyt_array(I_syn, units="A", name="Synaptic current").in_units("pA"),
    )


def test():
    constant_electrode_current = np.ones(time_grid.N) * 100 * pA
    no_synaptic_current = np.zeros(time_grid.N)
    sim = izh_neuron(
        no_synaptic_current, constant_electrode_current, time_grid, **izh_params
    )
    plt.plot(time_grid.t, sim.V_m)
