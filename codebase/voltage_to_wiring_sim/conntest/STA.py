"""
Spike-triggered averaging.
"""

import matplotlib.pyplot as plt
import numpy as np
from numba import prange

from ..support import Signal, TimeGrid, compile_to_machine_code
from ..support.spike_train import SpikeTimes, to_indices
from ..support.units import mV, ms, Quantity


def calculate_STA(
    VI_signal: Signal,
    spike_times: SpikeTimes,
    window_duration: Quantity
) -> Signal:
    dt = VI_signal.timestep
    spike_indices = to_indices(spike_times, dt)
    window_tg = TimeGrid(window_duration, dt)
    STA = _calc_STA(VI_signal, spike_indices, window_tg.N)
    return Signal(STA, dt)


@compile_to_machine_code(parallel=True)
def _calc_STA(
    VI_signal: np.ndarray,
    spike_indices: np.ndarray,
    window_length: int,
) -> np.ndarray:
    num_spikes = len(spike_indices)
    num_windows = 0
    STA = np.zeros(window_length)
    for i in prange(num_spikes):
        start_ix = spike_indices[i]
        end_ix = start_ix + window_length
        if end_ix < len(VI_signal):
            STA += VI_signal[start_ix:end_ix]
            num_windows += 1
    return STA / num_windows


def plot_STA(STA: Signal, ax=None, **kwargs):
    if ax is None:
        fig, ax = plt.subplots()
    
    ax.plot(STA.time / ms, STA / mV, **kwargs)
    ax.set_xlabel("Time after spike (ms)")
    ax.set_ylabel("Spike triggered <VI signal> (mV)")
