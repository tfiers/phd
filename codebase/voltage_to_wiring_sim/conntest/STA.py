"""
Spike-triggered averaging.
"""

import numpy as np
from matplotlib.axes import Axes
from numba import prange

from ..support import Signal, compile_to_machine_code, to_num_timesteps
from ..support.spike_train import SpikeTimes, to_indices
from ..support.units import Quantity, mV, ms
from ..support.util import create_if_None


def calculate_STA(
    VI_signal: Signal,
    spike_times: SpikeTimes,
    window_duration: Quantity,
) -> Signal:
    dt = VI_signal.timestep
    spike_indices = to_indices(spike_times, dt)
    window_length = to_num_timesteps(window_duration, dt)
    STA = _calc_STA(VI_signal, spike_indices, window_length)
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


def plot_STA(STA: Signal, ax: Axes = None, **kwargs):
    ax = create_if_None(ax)
    ax.plot(STA.time / ms, STA / mV, **kwargs)
    ax.set_xlabel("Time after spike (ms)")
    ax.set_ylabel("STA of VI signal (mV)")
    return ax
