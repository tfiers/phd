# We use the same approach as in eg Dayan & Abott to generate (approximate) Poisson
# spike times. (Approximate Poisson because we ignore the possibility of a neuron
# spiking more than once in the same small timebin `dt`).

import numpy as np
from numpy import ndarray

from .support.data_types import InterSpikeIntervals, SpikeTimes
from .support.plot_style import figsize
from .support.time_grid import TimeGrid
from .support.units import Hz, Quantity, ms, second
from .support.util import subplots


def generate_Poisson_spikes(
    spike_rate: Quantity,
    simulation_duration: Quantity,
) -> SpikeTimes:
    """
    Create a list of Poisson-distributed spike times by drawing inter-spike-intervals
    from an exponential distribution. The spikes are ordered (increasing in time).
    """
    # Exponential distributions are either parametrized by a scale, β, or equivalently,
    # by a rate, λ.
    λ = spike_rate
    β = 1 / λ
    # We don't know how many spikes we need to generate to get to the end of the
    # simulation. Hence our strategy is to generate a bunch of spikes, check if we have
    # enough, and if not, generate a bunch more and repeat.
    expected_num_spikes = simulation_duration / spike_rate
    num_new_spikes_per_iteration = round(expected_num_spikes)
    spike_times: np.ndarray = []
    get_last_spike = lambda: spike_times[-1]
    is_first_iteration = True
    while True:
        new_ISIs = np.random.exponential(β, num_new_spikes_per_iteration)
        new_spike_times = to_spike_train(
            new_ISIs,
            start_offset=0 * second if is_first_iteration else get_last_spike(),
        )
        spike_times = np.concatenate((spike_times, new_spike_times))
        if get_last_spike() >= simulation_duration:
            # We have now generated enough spikes. In fact, we have too many. Select and
            # return a subset.
            spike_falls_within_time_grid = spike_times < simulation_duration
            selected_spike_times = spike_times[spike_falls_within_time_grid]
            return selected_spike_times
        else:
            is_first_iteration = False
            continue


def to_spike_train(
    ISIs: InterSpikeIntervals,
    start_offset: Quantity = 0 * second,
) -> SpikeTimes:
    spike_train = start_offset + np.cumsum(ISIs)
    return spike_train


def plot(t, spike_train: "Signal", *plot_args, **plot_kwargs):
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
