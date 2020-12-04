"""
Spike-triggered averaging.
"""

import matplotlib.pyplot as plt
import numpy as np
from numba import njit

from .spike_trains import spike_train_to_indices
from .support.time_grid import TimeGrid
from .support.units import mV, ms
from .support.data_types import Signal


def calculate_STA(
    VI_signal: Signal,
    spike_train: np.ndarray,
    main_tg: TimeGrid,
    window_tg: TimeGrid,
) -> Signal:
    spike_indices = spike_train_to_indices(spike_train)
    # windows = make_windows(VI_signal, spike_indices, main_tg, window_tg)
    # STA = np.mean(windows, axis=0)
    STA = _calc_STA(VI_signal, spike_indices, main_tg.N, window_tg.N)
    return STA


@njit(cache=True)
def _calc_STA(
    VI_signal: np.ndarray,
    spike_indices: np.ndarray,
    main_N: int,
    window_N: int,
) -> np.ndarray:
    num_windows = len(spike_indices)
    STA = np.zeros(window_N)
    for i in range(num_windows):
        start_ix = spike_indices[i]
        end_ix = start_ix + window_N
        if end_ix < main_N:
            STA += VI_signal[start_ix:end_ix]
        else:
            num_windows -= 1
    return STA / num_windows


def plot_STA(STA: Signal, window_tg: TimeGrid, ax=None, **kwargs):
    if ax is None:
        fig, ax = plt.subplots()
    ax.plot(window_tg.t / ms, STA / mV, **kwargs)
    ax.set_xlabel("Time after spike (ms)")
    ax.set_ylabel("Spike triggered <VI signal> (mV)")
