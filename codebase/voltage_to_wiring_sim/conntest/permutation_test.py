from __future__ import annotations

from dataclasses import dataclass

import matplotlib.pyplot as plt
import numpy as np

from .STA import calculate_STA
from ..sim.spike_trains import to_ISIs, to_spike_train
from ..support import Signal
from ..support.data_types import SpikeTimes
from ..support.units import Array, Quantity


def shuffle(spike_train: SpikeTimes, num_shuffles: int) -> list[SpikeTimes]:
    ISIs = to_ISIs(spike_train)
    shuffled_trains = []
    for i in range(num_shuffles):
        shuffled_ISIs = np.random.permutation(ISIs)
        # We don't use `np.random.shuffle` as that's in place (`permutation` calls
        # `shuffle` anyway).
        shuffled_trains.append(to_spike_train(shuffled_ISIs))
    return shuffled_trains


def test_connection(
    spike_train: SpikeTimes,
    VI_signal: Signal,
    window_duration: Quantity,
    num_shuffles: int,
) -> tuple[(ConnectionTestData, ConnectionTestSummary)]:
    """
    Generate the data to test the following hypothesis:

        The neuron that generated `spike_train` is connected to the neuron from which
        `VI_signal` was recorded.

    (The null hypothesis is that they are NOT connected).

    Does this by looking for a postsynaptic potential in `VI_signal` through spike
    triggered averaging, both using the original `spike_train` and randomly shuffled
    versions of it.
    """

    shuffled_spike_trains = shuffle(spike_train, num_shuffles)

    def calc_STA_height(spike_train):
        STA_window = calculate_STA(VI_signal, spike_train, window_duration)
        return np.max(STA_window) - np.min(STA_window)

    original_STA_height = calc_STA_height(spike_train)
    shuffled_STA_heights = np.array(
        [calc_STA_height(train) for train in shuffled_spike_trains]
    )

    num_shuffled_STAs_larger = np.sum(shuffled_STA_heights > original_STA_height)
    if num_shuffled_STAs_larger == 0:
        p_value = 1 / num_shuffles
        p_value_type = PValueType.LIMIT
    else:
        p_value = num_shuffled_STAs_larger / num_shuffles
        p_value_type = PValueType.EQUAL

    shuffled_STA_height_mean = np.mean(shuffled_STA_heights)
    relative_STA_height = original_STA_height / shuffled_STA_height_mean

    return ConnectionTestData(
        shuffled_spike_trains,
        original_STA_height,
        shuffled_STA_heights,
        shuffled_STA_height_mean,
    ), ConnectionTestSummary(
        p_value,
        p_value_type,
        relative_STA_height,
    )


@dataclass
class ConnectionTestData:
    shuffled_spike_trains: list[SpikeTimes]
    original_STA_height: Quantity
    #    Maximum height of STA window using original spike train.
    shuffled_STA_heights: Array
    #    Maximum heights of STA windows using shuffled spike trains.
    shuffled_STA_height_mean: Quantity


@dataclass
class ConnectionTestSummary:
    p_value: float  # p(H0 | data)
    p_value_type: PValueType
    relative_STA_height: float


class PValueType:
    LIMIT = "<"
    EQUAL = "="


def plot(data: ConnectionTestData, bins=12, ax=None):
    import seaborn as sns
    from voltage_to_wiring_sim.support.units import mV

    if ax is None:
        _, ax = plt.subplots()

    sns.rugplot(
        data.shuffled_STA_heights / mV,
        label="Shuffled spike trains",
        ax=ax,
    )
    sns.distplot(
        data.shuffled_STA_heights / mV,
        bins=bins,
        kde=False,  # Make y-axis labels give count in each bin. (Instead of a density).
        ax=ax,
    )
    ax.axvline(
        data.original_STA_height / mV,
        color="C1",
        label="Real spike train",
    )
    ax.set_xlabel("STA height (mV)")
    ax.legend()
    return ax


def test():
    import voltage_to_wiring_sim as v
    from voltage_to_wiring_sim.support.units import second, ms, Hz, nS

    tg = v.TimeGrid(duration=1 * second, timestep=0.2 * ms)
    st = v.generate_Poisson_spikes(spike_rate=30 * Hz, simulation_duration=tg.duration)
    g_syn = v.calc_synaptic_conductance(tg, st, Δg_syn=0.9 * nS, τ_syn=0.7 * ms)
    sim = v.simulate_izh_neuron(tg, v.sim.neuron_params.cortical_RS, g_syn)
    test_connection(st, sim.V_m, window_duration=80 * ms, num_shuffles=10)
