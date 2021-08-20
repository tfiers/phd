from dataclasses import dataclass

import numpy as np

from ..support.spike_train import SpikeTimes, plot_spike_train, to_spike_train
from ..support.units import Hz, Quantity, ms, second


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
    expected_num_spikes = simulation_duration * spike_rate
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


@dataclass
class InputSpikeTrain:
    spikes: SpikeTimes
    v_syn: float  # synaptic reversal potential


def test():
    n_in = 20
    spike_trains = [
        generate_Poisson_spikes(spike_rate=1 * Hz, simulation_duration=1 * second)
        for _incoming_neuron in range(n_in)
    ]
    # Aggregate spikes for all incoming neurons
    all_spikes = np.concatenate(spike_trains)
    fig, ax = plot_spike_train(all_spikes / ms)
    ax.set_xlabel("Time (ms)")
