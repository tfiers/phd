# We use the same approach as in eg Dayan & Abott to generate (approximate) Poisson
# spike times. (Approximate Poisson because we ignore the possibility of a neuron
# spiking more than once in the same small timebin `dt`).

from numpy import ndarray
from numpy.random import random

from .plot_style import figsize
from .time_grid import TimeGrid
from .units import Hz, Quantity, ms, second
from .util import subplots


def generate_Poisson_spike_train(time_grid: TimeGrid, f_spike: Quantity) -> ndarray:
    """
    Simulate a Poisson spiking neuron.
    :param f_spike:  Mean spiking frequency
    :return: Array of length `time_grid.N`. "1" at spike times, "0" elsewhere.
    """
    return f_spike * time_grid.dt > random(time_grid.N)


def plot(t, spike_train, *plot_args, **plot_kwargs):
    fig, ax = subplots(**figsize(aspect=0.05, width=600))
    ax.plot(t, spike_train, *plot_args, **plot_kwargs)
    ax.axes.get_yaxis().set_visible(False)
    ax.spines["left"].set_visible(False)
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
    plot(tg.t.in_units(ms), all_spikes)
