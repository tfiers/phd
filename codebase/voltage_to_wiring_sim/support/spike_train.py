from typing import Any, NewType, Optional, Tuple

import numpy as np
from matplotlib.axes import Axes
from nptyping import NDArray

from .plot_style import figsize
from .units import Quantity, second
from .util import subplots


NumSpikes = Any


SpikeTimes = NewType("SpikeTimes", NDArray[(NumSpikes,), float])
#   A collection of spike times; i.e. not a full "0/1" signal.


SpikeIndices = NewType("SpikeIndices", NDArray[(NumSpikes,), int])
#   Like `SpikeTimes`, but expressed in number of samples since the start of the signal.


InterSpikeIntervals = NewType("InterSpikeIntervals", NDArray[(NumSpikes,), float])


def to_spike_train(
    ISIs: InterSpikeIntervals,
    start_offset: Quantity = 0 * second,
) -> SpikeTimes:
    return start_offset + np.cumsum(ISIs)


def to_ISIs(spike_train: SpikeTimes) -> InterSpikeIntervals:
    """
    First element is not strictly an ISI, but rather the time of the first spike after
    the beginning of the time-series.
    """
    return np.diff(spike_train, prepend=[0])


def to_indices(spike_times: SpikeTimes, dt: Quantity) -> SpikeIndices:
    return np.round(spike_times / dt).astype(int)


TimeSlice = Tuple[(Quantity, Quantity)]  # (start, stop) times.


def plot_spike_train(
    spike_train: SpikeTimes,
    time_range: Optional[TimeSlice] = None,
    ax: Optional[Axes] = None,
    linewidth=0.5,
    alpha=1,
    **eventplot_kwargs,
):
    if ax:
        fig = ax.figure
    else:
        fig, ax = subplots(**figsize(aspect=20, width=600))
    if time_range is None:
        spikes_to_plot = spike_train
    else:
        start, stop = time_range
        subset_mask = np.logical_and(start < spike_train, spike_train < stop)
        spikes_to_plot = spike_train[subset_mask]
        ax.set_xlim(*time_range)
    eventplot_kwargs.update(linewidth=linewidth, alpha=alpha)
    ax.eventplot(spikes_to_plot, **eventplot_kwargs)
    ax.axes.get_yaxis().set_visible(False)
    ax.spines["left"].set_visible(False)
    ax.set_xlabel("Time (s)")
    return fig, ax
