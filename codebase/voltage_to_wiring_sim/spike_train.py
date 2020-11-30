# We use the same approach as in eg Dayan & Abott to generate (approximate) Poisson
# spike times. (Approximate Poisson because we ignore the possibility of a neuron
# spiking more than once in the same small timebin `dt`).

import numpy as np
from numpy import ndarray
from numpy.random import random

from .support.plot_style import figsize
from .support.time_grid import TimeGrid
from .support.units import Hz, Quantity, ms, second
from .support.util import subplots
from .support.data_types import SpikeIndices, Signal


def generate_Poisson_spike_train(time_grid: TimeGrid, f_spike: Quantity) -> ndarray:
    """
    Simulate a Poisson spiking neuron.
    :param f_spike:  Mean spiking frequency
    :return: Array of length `time_grid.N`. "1" at spike times, "0" elsewhere.
    """
    return f_spike * time_grid.dt > random(time_grid.N)


def spike_train_to_indices(spike_train: Signal) -> np.ndarray:
    # `nonzero` returns a tuple (one element for each array dimension).
    (spike_indices,) = np.nonzero(spike_train)
    return spike_indices


def spike_train_from_indices(spike_indices: np.ndarray, time_grid: TimeGrid) -> Signal:
    output = np.zeros(time_grid.N)
    output[spike_indices] = 1
    return output


def plot(t, spike_train: Signal, *plot_args, **plot_kwargs):
    fig, ax = subplots(**figsize(aspect=0.05, width=600))
    ax.plot(t, spike_train, *plot_args, **plot_kwargs)
    ax.axes.get_yaxis().set_visible(False)
    ax.spines["left"].set_visible(False)
    ax.set_xlabel("Time (s)")
    return fig, ax


def test():
    f_spike = 1 * Hz
    n_in = 20
    tg = TimeGrid(1 * second, 0.1 * ms)
    spike_trains = [
        generate_Poisson_spike_train(tg, f_spike) for _incoming_neuron in range(n_in)
    ]
    # Aggregate spikes for all incoming neurons
    all_spikes = sum(spike_trains)
    # plot(tg.t.in_units(ms), all_spikes)
    fig, ax = plot(tg.t / ms, all_spikes)
    ax.set_xlabel("Time (ms)")
