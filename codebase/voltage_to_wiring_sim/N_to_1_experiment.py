"""
Pipeline combining the sim/ and conntest/ packages.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from matplotlib.axes import Axes
from matplotlib.figure import Figure
from nptyping import NDArray

from .conntest.permutation_test import ConnectionTestSummary, test_connection
from .sim.imaging import add_VI_noise
from .sim.izhikevich_neuron import IzhikevichOutput, simulate_izh_neuron
from .sim.neuron_params import IzhikevichParams, cortical_RS
from .sim.poisson_spikes import generate_Poisson_spikes
from .sim.synapses import calc_synaptic_conductance
from .support import Signal, plot_signal, to_bounds
from .support.plot_style import figsize
from .support.spike_train import SpikeTimes, plot_spike_train
from .support.units import Hz, Quantity, mV, minute, ms, nS
from .support.util import create_if_None, timed_loop


@dataclass
class N_to_1_SimParams:
    sim_duration: Quantity
    timestep: Quantity
    num_spike_trains: int
    p_connected: float
    spike_rate: Quantity  # same for each spike train
    Δg_syn: Quantity
    τ_syn: Quantity
    neuron_params: IzhikevichParams
    imaging_spike_SNR: float


default_params = N_to_1_SimParams(
    sim_duration=10 * minute,
    timestep=0.1 * ms,
    num_spike_trains=30,
    p_connected=0.5,
    spike_rate=20 * Hz,
    Δg_syn=0.8 * nS,
    τ_syn=7 * ms,
    neuron_params=cortical_RS,
    imaging_spike_SNR=10,
)


def simulate(params: N_to_1_SimParams) -> N_to_1_SimData:

    # 1. Biology model
    spike_trains_list = [
        generate_Poisson_spikes(params.spike_rate, params.sim_duration)
        for _ in range(params.num_spike_trains)
    ]
    spike_trains = np.array(spike_trains_list, dtype=object)
    num_connected = round(params.p_connected * params.num_spike_trains)
    is_connected = np.zeros(params.num_spike_trains, dtype=bool)
    is_connected[:num_connected] = True
    connected_spike_trains = spike_trains[is_connected]

    all_incoming_spikes = np.concatenate(connected_spike_trains)
    g_syn = calc_synaptic_conductance(
        params.sim_duration,
        params.timestep,
        all_incoming_spikes,
        params.Δg_syn,
        params.τ_syn,
    )
    izh_output = simulate_izh_neuron(
        params.sim_duration, params.timestep, params.neuron_params, g_syn
    )

    # 2. Imaging model
    VI_signal = add_VI_noise(
        izh_output.V_m, params.neuron_params, params.imaging_spike_SNR
    )

    return N_to_1_SimData(
        spike_trains,
        is_connected,
        all_incoming_spikes,
        g_syn,
        izh_output,
        VI_signal,
    )


NumSpikeTrains = Any


@dataclass
class N_to_1_SimData:
    spike_trains: NDArray[(NumSpikeTrains,), SpikeTimes]
    is_connected: NDArray[(NumSpikeTrains,), bool]
    all_incoming_spikes: SpikeTimes
    g_syn: Signal
    izh_output: IzhikevichOutput
    VI_signal: Signal


def get_index_of_first_connected_train(sim_data: N_to_1_SimData) -> int:
    return np.nonzero(sim_data.is_connected)[0][0]


def test_connections(sim_data: N_to_1_SimData):
    test_data = []
    test_summaries = []
    for spike_train in timed_loop(sim_data.spike_trains, "Testing connections"):
        data, summary = test_connection(
            spike_train,
            sim_data.VI_signal,
            window_duration=100 * ms,
            num_shuffles=100,
        )
        test_data.append(data)
        test_summaries.append(summary)
    return test_data, test_summaries


def sim_and_eval():
    ...


def plot_sim_slice(sim_data: N_to_1_SimData, t_start: Quantity, duration: Quantity):
    fig: Figure = plt.figure(**figsize(width=700, aspect=1.8))
    ax_layout = [
        [[["selected_train"], ["all_spikes"]], "V_m"],
        ["g_syn", "VI_sig"],
    ]
    axes = fig.subplot_mosaic(ax_layout)
    bounds = to_bounds(t_start, duration)
    selected_spike_train = get_index_of_first_connected_train(sim_data)
    plot_spike_train(
        sim_data.spike_trains[selected_spike_train],
        bounds,
        axes["selected_train"],
    )
    axes["selected_train"].set(
        title=f"Spike train #{selected_spike_train}",
        xlabel="",
        xticklabels=[],
    )
    plot_spike_train(
        sim_data.all_incoming_spikes,
        bounds,
        axes["all_spikes"],
    )
    axes["all_spikes"].set(
        title="All incoming spikes",
        xlabel="",
        xticklabels=[],
    )
    plot_signal(
        sim_data.izh_output.V_m.slice(t_start, duration) / mV,
        axes["V_m"],
    )
    axes["V_m"].set(
        ylabel="$V_{mem}$ (mV)",
        xticklabels=[],
        xlim=bounds,
    )
    plot_signal(
        sim_data.VI_signal.slice(t_start, duration) / mV,
        axes["VI_sig"],
    )
    axes["VI_sig"].set(
        xlabel="Time (s)",
        ylabel="VI signal",
        xlim=bounds,
    )
    plot_signal(
        sim_data.g_syn.slice(t_start, duration) / nS,
        axes["g_syn"],
    )
    axes["g_syn"].set(
        xlabel="Time (s)",
        ylabel="$G_{syn}$ (nS)",
        xlim=bounds,
    )
    plt.tight_layout()  # Fix ylabels of right subplots overlapping with left subplots
    # Spike train plots are too high: their titles overlap each other.
    for ax in (axes["selected_train"], axes["all_spikes"]):
        bb = ax.get_position()
        ax.set_position([bb.x0, bb.y0, bb.width, bb.height * 0.4])


def _connected_labels(sim_data: N_to_1_SimData) -> list[str]:
    return [
        "Connected" if connected else "Not connected"
        for connected in sim_data.is_connected
    ]


def plot_p_values(
    test_summaries: list[ConnectionTestSummary],
    sim_data: N_to_1_SimData,
    ax: Axes = None,
):
    p_values = [summary.p_value for summary in test_summaries]
    ax = create_if_None(ax, **figsize(aspect=3))
    sns.histplot(
        x=p_values,
        hue=_connected_labels(sim_data),
        multiple="stack",
        binwidth=0.01,
        ax=ax,
    )
    ax.set(
        xlabel="p-value",
        ylabel="Nr. of spike trains",
        xlim=[0, 1],
    )
    return ax


def plot_relative_STA_heights(
    test_summaries: list[ConnectionTestSummary],
    sim_data: N_to_1_SimData,
    ax: Axes = None,
):
    rel_heights = [summary.relative_STA_height for summary in test_summaries]
    ax = create_if_None(ax, **figsize(aspect=3))
    sns.histplot(
        x=rel_heights,
        hue=_connected_labels(sim_data),
        multiple="stack",
        binwidth=0.02,
        ax=ax,
    )
    ax.set(
        xlabel="STA height / mean shuffled STA height",
        ylabel="Nr. of spike trains",
    )
    return ax
