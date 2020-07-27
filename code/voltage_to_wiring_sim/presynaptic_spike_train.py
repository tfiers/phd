# We use the same approach as in eg Dayan & Abott to generate (approximate) Poisson
# spike times. (Approximate Poisson because we ignore the possibility of a neuron
# spiking more than once in the same small timebin `dt`).

import matplotlib.pyplot as plt
from joblib import Memory
from numpy import zeros
from numpy.random import random, seed
from unyt import Hz

from .plot_style import FigSizeCalc
from .time_grid import short_time_grid
from .units import strip_input_units

#

# Mean spiking frequency per every incoming neuron.
f_spike = 1 * Hz

# Number of incoming neurons
n_in = 20

# Fix RNG seed to generate same random sequence and thus get same results every
# script run.
seed(0)


@strip_input_units
def generate_spike_train(f_spike, time_grid):
    spikes = zeros(time_grid.N)
    for i in range(time_grid.N):
        spikes[i] = f_spike * time_grid.dt > random()
    return spikes


memory = Memory(".", verbose=False)


@memory.cache
def generate_spike_trains(N):
    return [
        generate_spike_train(f_spike, short_time_grid) for incoming_neuron in range(N)
    ]


spike_trains = generate_spike_trains(n_in)

# Aggregate spikes for all incoming neurons
all_spikes = sum(spike_trains)


def show():
    fig, ax = plt.subplots(**FigSizeCalc(fig_height_vs_width=0.2).fig_kwargs)
    ax.plot(short_time_grid.t, all_spikes)
    ax.axes.get_yaxis().set_visible(False)
    ax.spines["left"].set_visible(False)
