"""
Integrate the ODE of the Izhikevich model neuron.

The real work happens in `_sim_izh()`.
"""
from dataclasses import asdict, dataclass
from functools import partial
from typing import Sequence

import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from matplotlib.axes import Axes

from .neuron_params import IzhikevichParams, cortical_RS
from ..support import Signal, compile_to_machine_code, to_num_timesteps
from ..support.spike_train import SpikeTimes, to_ISIs
from ..support.units import Quantity, mV, ms, pA
from ..support.plot_util import new_plot_if_None, figsize


@dataclass
class IzhikevichOutput:
    V_m: Signal
    u: Signal
    I_syn: Signal
    spike_times: SpikeTimes

    # def __post_init__(self):
    #     self.V_m.name = "Membrane voltage"
    #     self.u.name = '"Slow current", u'
    #     self.I_syn.name = "Synaptic current"


def simulate_izh_neuron(
    sim_duration: Quantity,
    timestep: Quantity,
    params: IzhikevichParams,
    v_syn: Sequence[float] = None,
    g_syn: Sequence[Signal] = None,
    I_e: Signal = None,
    pure_python=False,
) -> IzhikevichOutput:

    num_timesteps = to_num_timesteps(sim_duration, timestep)

    if g_syn is None:
        v_syn = []
        g_syn = [[]]
    else:
        g_syn = np.stack([g.data for g in g_syn])

    if I_e is None:
        I_e = Signal(np.zeros(num_timesteps) * pA, timestep)

    V_m = Signal(np.empty(num_timesteps) * mV, timestep)
    u = Signal(np.empty(num_timesteps) * pA, timestep)
    I_syn = Signal(np.empty(num_timesteps) * pA, timestep)

    if pure_python:
        f = _sim_izh
    else:
        f = compile_to_machine_code(_sim_izh)

    spikes = f(V_m, u, I_syn, I_e, g_syn, v_syn, timestep, **asdict(params))
    spike_times = np.array(spikes) * timestep

    return IzhikevichOutput(V_m, u, I_syn, spike_times)


# Pure Python/NumPy function that can be compiled to compact machine code by Numba,
# without any overhead due to generic Python object processing.
# fmt: off
def _sim_izh(
    v, u, I_syn,  # Empty arrays of length T, filled in place during simulation.
    I_e,  # Input array of length T (num timesteps).
    g_syn,  # Input S x T array, with S the number of input synapses.
    v_syn,  # Input array of length S.
    dt,  # Timestep (scalar).
    v_r, k, v_t,
        C, a, b, v_peak, c, d  # Scalars. See `IzhikevichParams` dataclass.
):
    dv_dt = lambda t: (k * (v[t] - v_r) * (v[t] - v_t) - u[t] - I_syn[t] + I_e[t]) / C
    du_dt = lambda t: a * (b * (v[t] - v_r) - u[t])
    spikes = []
    T = len(v)
    S = len(v_syn)
    for t in range(T):
        if t == 0:
            v[t] = v_r
            u[t] = 0
        else:
            v[t] = v[t-1] + dt * dv_dt(t-1)
            u[t] = u[t-1] + dt * du_dt(t-1)
            if v[t] >= v_peak:
                spikes.append(t)
                v[t-1] = v_peak
                v[t] = c
                u[t] += d
        for s in range(S):
            I_syn[t] += g_syn[s, t] * (v[t] - v_syn[s])
    return spikes

# fmt: on


def show_output_spike_stats(output: IzhikevichOutput, ax: Axes = None):
    ISIs = to_ISIs(output.spike_times)
    ax = new_plot_if_None(ax, **figsize(aspect=4))
    sns.histplot(ISIs / ms, ax=ax)
    ax.set_xlabel("Inter-spike interval (ms)")
    ax.set_ylabel("# spike pairs")
    ax.set_xlim(left=0)
    plt.show()
    print(f"Output spike rate (1 / median ISI): {1 / np.median(ISIs):.3G} Hz")
    return ax


def test():
    sim_duration = 200 * ms
    timestep = 0.5 * ms
    N = to_num_timesteps(sim_duration, timestep)
    constant_input = np.ones(N) * 80 * pA
    f = partial(
        simulate_izh_neuron,
        sim_duration,
        timestep,
        cortical_RS,
        I_e=constant_input,
        g_syn=None,
    )
    sim = f(pure_python=True)
    # sim_fast = f(pure_python=False)
    #   Numba can't work with empty list (v_syn=[]).
    plt.plot(sim.V_m.time / ms, sim.V_m)
    plt.xlabel("Time (ms)")
