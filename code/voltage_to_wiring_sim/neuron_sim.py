from dataclasses import dataclass, asdict

import matplotlib.pyplot as plt
from numpy import zeros, empty, ones
from numba import jit
from unyt import unyt_array
from voltage_to_wiring_sim.neuron_params import cortical_RS

from .units import pA, strip_input_units
from .neuron_params import IzhikevichParams
from .time_grid import short_time_grid, TimeGrid


@dataclass
class SimResult:
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


@strip_input_units
def simulate_izh_neuron(
    time_grid: TimeGrid,
    params: IzhikevichParams,
    g_syn: unyt_array = None,
    I_e: unyt_array = None,
) -> SimResult:

    if g_syn is None:
        g_syn = zeros(time_grid.N) * pA

    if I_e is None:
        I_e = zeros(time_grid.N) * pA

    # Pure Python/Numpy function that can be compiled to compact machine code by Numba,
    # without any overhead due to generic Python object processing.
    # (Numba can't yet handle data classes, alas; so we have to unpack them, as
    # arguments).
    @jit
    def sim(N, dt, v_r, v_syn, k, v_t, C, a, b, v_peak, c, d):
        v = empty(N)
        u = empty(N)
        I_syn = empty(N)
        v[0] = v_r
        u[0] = 0
        for i in range(N - 1):
            I_syn[i] = g_syn[i] * (v[i] - v_syn)
            dv_dt = (k * (v[i] - v_r) * (v[i] - v_t) - u[i] - I_e[i]) / C
            du_dt = a * (b * (v[i] - v_r) - u[i])
            # First order ('Euler') ODE integration.
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
        V_m=unyt_array(v, units="V"),
        u=unyt_array(u, units="A"),
        I_syn=unyt_array(I_syn, units="A"),
    )


def test():
    constant_electrode_current = ones(short_time_grid.N) * 100 * pA
    sim = simulate_izh_neuron(
        short_time_grid, cortical_RS, g_syn=None, I_e=constant_electrode_current
    )
    plt.plot(short_time_grid.t, sim.V_m)
