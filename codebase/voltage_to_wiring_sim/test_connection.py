from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .STA import calculate_STA
from .spike_trains import shuffle
from .support import Signal
from .support.data_types import SpikeTimes
from .support.units import Array, Quantity


def test_connection(
    spike_train: SpikeTimes,
    VI_signal: Signal,
    window_duration: Quantity,
    num_shuffles: int,
) -> tuple[(TestData, TestSummary)]:
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

    def STA_peak_height(spike_train):
        STA_window = calculate_STA(VI_signal, spike_train, window_duration)
        return np.max(STA_window)

    original_peak_height = STA_peak_height(spike_train)
    shuffled_peak_heights = np.array(
        STA_peak_height(shuffled_spike_train)
        for shuffled_spike_train in shuffled_spike_trains
    )

    num_shuffled_peaks_larger = np.sum(shuffled_peak_heights > original_peak_height)
    if num_shuffled_peaks_larger == 0:
        p_value = 1 / num_shuffles
        p_value_type = PValueType.LIMIT
    else:
        p_value = num_shuffled_peaks_larger / num_shuffles
        p_value_type = PValueType.EQUAL

    mean_shuffled_peak_height = np.mean(shuffled_peak_heights)
    relative_peak_height = original_peak_height / mean_shuffled_peak_height

    return TestData(
        shuffled_spike_trains,
        original_peak_height,
        shuffled_peak_heights,
    ), TestSummary(
        p_value,
        p_value_type,
        mean_shuffled_peak_height,
        relative_peak_height,
    )


@dataclass
class TestData:
    shuffled_spike_trains: list[SpikeTimes]
    original_peak_height: Quantity
    #    Maximum height of STA window using original spike train.
    shuffled_peak_heights: Array
    #    Maximum heights of STA windows using shuffled spike trains.


@dataclass
class TestSummary:
    """
    Summarizing values calculated from `TestData`. The p-value is the probability of the
    null hypothesis (see `test_connection`), given the spike train and VI data.
    """

    p_value: float
    p_value_type: PValueType
    mean_shuffled_peak_height: Quantity
    relative_peak_height: float


class PValueType:
    LIMIT = "<"
    EQUAL = "="
