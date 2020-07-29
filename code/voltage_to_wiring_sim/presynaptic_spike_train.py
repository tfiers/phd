# We use the same approach as in eg Dayan & Abott to generate (approximate) Poisson
# spike times. (Approximate Poisson because we ignore the possibility of a neuron
# spiking more than once in the same small timebin `dt`).

import matplotlib.pyplot as plt
from numba import jit
from numpy import zeros
from numpy.random import random, seed

from .plot_style import figsize
from .time_grid import TimeGrid
from .units import Hz, Quantity, inputs_as_raw_data, ms, s


# Fix RNG seed to generate same random sequence and thus get same results every
# script run.
seed(0)


@inputs_as_raw_data
@jit
def _gen_spike_train(f_spike, N, dt):
    spikes = zeros(N)
    for i in range(N):
        spikes[i] = f_spike * dt > random()
    return spikes


def generate_spike_train(f_spike: Quantity, tg: TimeGrid):
    return _gen_spike_train(f_spike, tg.N, tg.dt)


def test():
    # Mean spiking frequency per every incoming neuron.
    f_spike = 1 * Hz
    # Number of incoming neurons
    n_in = 20
    tg = TimeGrid(1 * s, 0.1 * ms)
    spike_trains = [
        generate_spike_train(f_spike, tg) for incoming_neuron in range(n_in)
    ]
    # Aggregate spikes for all incoming neurons
    all_spikes = sum(spike_trains)
    fig, ax = plt.subplots(**figsize(aspect=0.2))
    ax.plot(tg.t, all_spikes)
    ax.axes.get_yaxis().set_visible(False)
    ax.spines["left"].set_visible(False)
