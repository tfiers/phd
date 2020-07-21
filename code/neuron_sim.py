import matplotlib.pyplot as plt
import numpy as np
from numba import jit
from unyt import V, mV, pA, unyt_array, s

from cortical_RS_neuron import izh_params
from time_grid import N, dt, t
from util import strip_input_units


@strip_input_units
def izh_neuron(I, dt, N, *, C, k, v_r, v_t, v_peak, a, b, c, d) -> unyt_array:
    """
    Input I and output v: arrays of length N.
    """
    v_t0 = v_r
    u_t0 = 0

    # Pure Python/Numpy function that can be compiled to compact machine code by Numba,
    # without any overhead due to generic Python object processing.
    @jit
    def sim():
        v = np.ones(N) * v_t0
        u = np.ones(N) * u_t0
        for i in range(N - 1):
            dv_dt = (k * (v[i] - v_r) * (v[i] - v_t) - u[i] + I[i]) / C
            du_dt = a * (b * (v[i] - v_r) - u[i])
            v[i + 1] = v[i] + dt * dv_dt
            u[i + 1] = u[i] + dt * du_dt
            if v[i + 1] >= v_peak:
                v[i] = v_peak
                v[i + 1] = c
                u[i + 1] = u[i + 1] + d
        return v

    # We work in base SI units, so the result is in volts.
    Vm = unyt_array(sim(), units=V, name="Membrane voltage")
    return Vm.in_units(mV)


def test():
    constant_input_current = 60 * pA * np.ones(N)
    Vm = izh_neuron(constant_input_current, dt, N, **izh_params)
    plt.figure(1, dpi=300)
    plt.plot(t+0.1*s, np.abs(Vm), "r.", ms=0.2)
    # plt.show()
    plt.plot(t, Vm, 'b.', ms=0.2)
