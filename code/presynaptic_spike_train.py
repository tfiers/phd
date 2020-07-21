# We use the same approach as in eg Dayan & Abott to generate (approximate) Poisson
# spike times. (Approximate Poisson because we ignore the possibility of a neuron
# spiking more than once in the same small timebin `dt`).

import matplotlib.pyplot as plt
import numpy as np
from numpy.random import random, seed
from unyt import Hz

from time_grid import dt, N, t
from util import strip_input_units


# Fix RNG seed to generate same random sequence and thus get same results every
# script run.
seed(0)


@strip_input_units
def generate_spikes(f_spike, N, dt):
    spikes = np.zeros(N)
    for i in range(N):
        spikes[i] = f_spike * dt > random()
    return spikes


# Mean spiking frequency per every incoming neuron.
f_spike = 1 * Hz
N_in = 20
spike_trains = [generate_spikes(f_spike, N, dt) for incoming_neuron in range(N_in)]
# Aggregate spikes for all incoming neurons
all_spikes = sum(spike_trains)


def show():
    plt.plot(t, all_spikes)
    plt.show()
