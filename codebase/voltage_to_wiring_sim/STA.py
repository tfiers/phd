"""
Spike-triggered averaging.
"""

import matplotlib.pyplot as plt
import numpy as np
from voltage_to_wiring_sim.support.time_grid import TimeGrid
from voltage_to_wiring_sim.support.units import Signal, mV, ms


def get_spike_indices(spike_train: Signal) -> np.ndarray:
    # `nonzero` returns a tuple (one element for each array dimension).
    (spike_indices,) = np.nonzero(spike_train)
    return spike_indices


def make_windows(
    VI_signal: Signal,
    spike_indices: np.ndarray,
    main_tg: TimeGrid,
    window_tg: TimeGrid,
):
    windows = []
    for ix in spike_indices:
        ix_end = ix + window_tg.N
        if ix_end < main_tg.N:
            windows.append(VI_signal[ix:ix_end])

    windows = np.stack(windows)
    return windows


def calculate_STA(
    VI_signal: Signal,
    spike_train: np.ndarray,
    main_tg: TimeGrid,
    window_tg: TimeGrid,
) -> Signal:
    spike_indices = get_spike_indices(spike_train)
    windows = make_windows(VI_signal, spike_indices, main_tg, window_tg)
    STA = windows.mean(axis=0)
    return STA


def plot_STA(STA: Signal, window_tg: TimeGrid, ax=None, **kwargs):
    if ax is None:
        fig, ax = plt.subplots()
    ax.plot(window_tg.t / ms, STA / mV, **kwargs)
    ax.set_xlabel("Time after spike (ms)")
    ax.set_ylabel("Spike triggered <VI signal> (mV)")
