# We use the same approach as in eg Dayan & Abott to generate (approximate) Poisson
# spike times. (Approximate Poisson because we ignore the possibility of a neuron
# spiking more than once in the same small timebin `dt`).

import matplotlib.pyplot as plt
from numba import jit
from numpy import ndarray, zeros
from numpy.random import random

from .plot_style import figsize
from .time_grid import TimeGrid
from .units import Hz, Quantity, inputs_as_raw_data, ms, s


def generate_spike_train(time_grid: TimeGrid, f_spike: Quantity) -> ndarray:
    """
    Simulate a Poisson spiking neuron.
    :param f_spike:  Mean spiking frequency
    :return: Array of length `time_grid.N`. "1" at spike times, "0" elsewhere.
    """
    return _gen_spike_train(time_grid.N, time_grid.dt, f_spike)


@inputs_as_raw_data
@jit
def _gen_spike_train(N, dt, f_spike):
    spikes = zeros(N)
    for i in range(N):
        spikes[i] = f_spike * dt > random()
    return spikes


def test():
    f_spike = 1 * Hz
    n_in = 20
    tg = TimeGrid(1 * s, 0.1 * ms)
    spike_trains = [
        generate_spike_train(tg, f_spike) for incoming_neuron in range(n_in)
    ]
    # Aggregate spikes for all incoming neurons
    all_spikes = sum(spike_trains)
    fig, ax = plt.subplots(**figsize(aspect=0.2))
    ax.plot(tg.t, all_spikes)
    ax.axes.get_yaxis().set_visible(False)
    ax.spines["left"].set_visible(False)
