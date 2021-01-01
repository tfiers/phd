"""
Wrapper/pipeline/workflow combining spike_trains.py, synapses.py, neuron_sim.py, and
imaging.py.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .imaging import add_VI_noise
from .neuron_params import IzhikevichParams, cortical_RS
from .neuron_sim import IzhikevichOutput, simulate_izh_neuron
from .spike_trains import SpikeTimes, generate_Poisson_spikes
from .support import Signal, TimeGrid
from .support.units import Hz, Quantity, minute, ms, nS
from .synapses import calc_synaptic_conductance


@dataclass
class N_to_1_SimParams:
    time_grid: TimeGrid
    num_incoming_spike_trains: int
    spike_rate: Quantity  # same for each spike train
    Δg_syn: Quantity
    τ_syn: Quantity
    neuron_params: IzhikevichParams
    imaging_spike_SNR: float


default_params = N_to_1_SimParams(
    time_grid=TimeGrid(duration=10 * minute, timestep=0.1 * ms),
    num_incoming_spike_trains=15,
    spike_rate=20 * Hz,
    Δg_syn=0.8 * nS,
    τ_syn=7 * ms,
    neuron_params=cortical_RS,
    imaging_spike_SNR=10,
)


def simulate(params: N_to_1_SimParams) -> N_to_1_SimResult:

    # 1. Biology model
    spike_trains = [
        generate_Poisson_spikes(params.spike_rate, params.time_grid.duration)
        for _ in range(params.num_incoming_spike_trains)
    ]
    all_incoming_spikes = np.concatenate(spike_trains)
    g_syn = calc_synaptic_conductance(
        params.time_grid, all_incoming_spikes, params.Δg_syn, params.τ_syn
    )
    izh_output = simulate_izh_neuron(params.time_grid, params.neuron_params, g_syn)

    # 2. Imaging model
    VI_signal = add_VI_noise(
        izh_output.V_m, params.neuron_params, params.imaging_spike_SNR
    )

    return N_to_1_SimResult(
        spike_trains, all_incoming_spikes, g_syn, izh_output, VI_signal
    )


@dataclass
class N_to_1_SimResult:
    spike_trains: list[SpikeTimes]
    all_incoming_spikes: SpikeTimes
    g_syn: Signal
    izh_output: IzhikevichOutput
    VI_signal: Signal
