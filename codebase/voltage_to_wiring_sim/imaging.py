import numpy as np

from .params import IzhikevichParams
from .support.signal import Signal


def add_VI_noise(
    voltage_trace: Signal,
    neuron_params: IzhikevichParams,
    VI_spike_SNR=10,  # See VI lit review
) -> Signal:
    spike_height = neuron_params.v_peak - neuron_params.v_r
    σ_noise = spike_height / VI_spike_SNR
    noise = np.random.randn(len(voltage_trace)) * σ_noise
    noisy_voltage_trace = voltage_trace + noise
    return noisy_voltage_trace
