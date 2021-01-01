"""
Wrapper/pipeline/workflow combining spike_trains.py, synapses.py, neuron_sim.py, and
imaging.py.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.figure import Figure

from .imaging import add_VI_noise
from .neuron_params import IzhikevichParams, cortical_RS
from .neuron_sim import IzhikevichOutput, simulate_izh_neuron
from .spike_trains import SpikeTimes, generate_Poisson_spikes, plot as plot_spike_train
from .support import Signal, TimeGrid
from .support.plot_style import figsize
from .support.units import Hz, Quantity, minute, ms, nS, mV
from .synapses import calc_synaptic_conductance


@dataclass
class N_to_1_SimParams:
    time_grid: TimeGrid
    num_incoming_spike_trains: int  # i.e. the "N" from the class/module name.
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


def plot(sim_result: N_to_1_SimResult, zoom: TimeGrid):
    fig: Figure = plt.figure(**figsize(width=700, aspect=1.8))
    ax_layout = [
        [[["selected_train"], ["all_spikes"]], "V_m"],
        ["g_syn", "VI_sig"],
    ]
    axes = fig.subplot_mosaic(ax_layout)
    plot_spike_train(
        sim_result.spike_trains[0],
        zoom.bounds,
        axes["selected_train"],
    )
    axes["selected_train"].set(
        title="One spike train",
        xlabel="",
        xticklabels=[],
    )
    plot_spike_train(
        sim_result.all_incoming_spikes,
        zoom.bounds,
        axes["all_spikes"],
    )
    axes["all_spikes"].set(
        title="All incoming spikes",
        xlabel="",
        xticklabels=[],
    )
    axes["V_m"].plot(
        zoom.time,
        sim_result.izh_output.V_m[zoom.i_slice] / mV,
    )
    axes["V_m"].set(
        ylabel="$V_{mem}$ (mV)",
        xticklabels=[],
        xlim=zoom.bounds,
    )
    axes["VI_sig"].plot(
        zoom.time,
        sim_result.VI_signal[zoom.i_slice] / mV,
    )
    axes["VI_sig"].set(
        xlabel="Time (s)",
        ylabel="VI signal",
        xlim=zoom.bounds,
    )
    axes["g_syn"].plot(
        zoom.time,
        sim_result.g_syn[zoom.i_slice] / nS,
    )
    axes["g_syn"].set(
        xlabel="Time (s)",
        ylabel="$G_{syn}$ (nS)",
        xlim=zoom.bounds,
    )
    plt.tight_layout()  # Fix ylabels of right subplots overlapping with left subplots
    # Spike train plots are too high: their titles overlap each other.
    for ax in (axes["selected_train"], axes["all_spikes"]):
        bb = ax.get_position()
        ax.set_position([bb.x0, bb.y0, bb.width, bb.height * 0.4])
