import matplotlib.pyplot as plt
import numpy as np

from .spike_trains import generate_Poisson_spikes, to_indices
from .support import Signal, TimeGrid, compile_to_machine_code
from .support.data_types import SpikeTimes
from .support.units import Hz, Quantity, ms, nS


def calc_synaptic_conductance(
    time_grid: TimeGrid,
    spike_times: SpikeTimes,
    Δg_syn: Quantity,
    τ_syn: Quantity,
    pure_python=False,
) -> Signal:
    """
    :param time_grid:  For how long and with which timestep do we simulate?
    :param spike_times:
    :param Δg_syn:  Increase in synaptic conductance per spike.
    :param τ_syn:  Synaptic conductance decay time constant.
    :return:  Array of length N, `g_syn`
    """
    g_syn = np.empty(time_grid.N) * nS
    # g_syn.name = "Synaptic conductance"
    sorted_spike_times = np.sort(spike_times)
    spike_indices = to_indices(sorted_spike_times, time_grid.timestep)
    #   (We don't put this in the compiled function as np.round(x) won't work yet with
    #   Numba without the `out=` argument. https://github.com/numba/numba/issues/4439).
    if pure_python:
        f = _calc_g_syn
    else:
        f = compile_to_machine_code(_calc_g_syn)
    f(g_syn, time_grid.timestep, spike_indices, Δg_syn, τ_syn)
    return Signal(g_syn, time_grid.timestep)


def _calc_g_syn(g_syn, dt, spike_indices, Δg_syn, τ_syn):
    num_spikes = len(spike_indices)
    num_processed_spikes = 0
    dgsyn_dt = lambda i: -g_syn[i] / τ_syn  # Exponential decay.
    for i in range(len(g_syn)):
        if i == 0:
            g_syn[i] = 0
        else:
            g_syn[i] = g_syn[i - 1] + dt * dgsyn_dt(i - 1)
        # Add conductance bump for every spike that falls within the current time bin i.
        while (
            num_processed_spikes < num_spikes
            and spike_indices[num_processed_spikes] == i
        ):
            g_syn[i] += Δg_syn
            num_processed_spikes += 1


def test():
    tg = TimeGrid(duration=300 * ms, dt=0.1 * ms)
    spikes = generate_Poisson_spikes(30 * Hz, tg.duration)
    Δg_syn = 2 * nS
    τ_syn = 7 * ms
    g_syn = calc_synaptic_conductance(tg, spikes, Δg_syn, τ_syn, pure_python=True)
    plt.plot(tg.t / ms, g_syn)
    plt.xlabel("Time (ms)")
