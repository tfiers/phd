from __future__ import annotations

from dataclasses import dataclass

from .support import Signal
from .support.data_types import SpikeTimes
from .support.units import Array, Quantity


def test_connection(
    spike_train: SpikeTimes,
    VI_signal: Signal,
    window_duration: Quantity,
    num_shuffles: int,
) -> tuple[ConnectionTestData, ConnectionTestSummary]:
    """
    Generate the data to test the following hypothesis:

        The neuron that generated `spike_train` is connected to the neuron from which
        `VI_signal` was recorded.

    (The null hypothesis is that they are NOT connected).

    Does this by looking for a postsynaptic potential in `VI_signal` through spike
    triggered averaging, both using the original `spike_train` and randomly shuffled
    versions of it.
    """
    ...


@dataclass
class ConnectionTestData:
    """ Maximum heights of STA windows (see `test_connection`). """

    peak_height: Quantity
    shuffled_peak_heights: Array


@dataclass
class ConnectionTestSummary:
    """
    Summarizing values calculated from `ConnectionTestData`. The p-value is the
    probability of the null hypothesis (see `test_connection`), given the spike train
    and VI data.
    """

    p_value: float
    p_value_type: PValueType
    mean_shuffled_peak_height: Quantity
    relative_peak_height: float


class PValueType:
    LIMIT = "<"
    EQUALITY = "="
