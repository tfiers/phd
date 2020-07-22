# We use the same approach as in eg Dayan & Abott to generate (approximate) Poisson
# spike times. (Approximate Poisson because we ignore the possibility of a neuron
# spiking more than once in the same small timebin `dt`).

import matplotlib.pyplot as plt
import numpy as np
from numpy.random import random, seed
from unyt import Hz

from time_grid import time_grid
from util import strip_input_units

# Mean spiking frequency per every incoming neuron.
f_spike = 1 * Hz

# Number of incoming neurons
n_in = 20

# Fix RNG seed to generate same random sequence and thus get same results every
# script run.
seed(0)


@strip_input_units
def generate_spikes(f_spike, time_grid):
    spikes = np.zeros(time_grid.N)
    for i in range(time_grid.N):
        spikes[i] = f_spike * time_grid.dt > random()
    return spikes


spike_trains = [generate_spikes(f_spike, time_grid) for incoming_neuron in range(n_in)]

# Aggregate spikes for all incoming neurons
all_spikes = sum(spike_trains)


def show():
    plt.plot(time_grid.t, all_spikes)
