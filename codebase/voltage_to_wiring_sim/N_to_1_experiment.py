"""
Pipeline combining the sim/ and conntest/ packages.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.figure import Figure
from nptyping import NDArray

from .sim.imaging import add_VI_noise
from .sim.izhikevich_neuron import IzhikevichOutput, simulate_izh_neuron
from .sim.neuron_params import IzhikevichParams, cortical_RS
from .sim.poisson_spikes import generate_Poisson_spikes
from .sim.synapses import calc_synaptic_conductance
from .support import Signal, to_bounds
from .support.plot_style import figsize
from .support.spike_train import SpikeTimes, plot_spike_train
from .support.units import Hz, Quantity, mV, minute, ms, nS


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


num_spike_trains = Any


@dataclass
class N_to_1_SimData:
    spike_trains: NDArray[(num_spike_trains,), SpikeTimes]
    is_connected: NDArray[(num_spike_trains,), bool]
    all_incoming_spikes: SpikeTimes
    g_syn: Signal
    izh_output: IzhikevichOutput
    VI_signal: Signal


def sim_and_eval():
    ...


def plot_slice(sim_result: N_to_1_SimData, t_start: Quantity, duration: Quantity):
    fig: Figure = plt.figure(**figsize(width=700, aspect=1.8))
    ax_layout = [
        [[["selected_train"], ["all_spikes"]], "V_m"],
        ["g_syn", "VI_sig"],
    ]
    axes = fig.subplot_mosaic(ax_layout)
    bounds = to_bounds(t_start, duration)
    plot_spike_train(
        sim_result.spike_trains[0],
        bounds,
        axes["selected_train"],
    )
    axes["selected_train"].set(
        title="One spike train",
        xlabel="",
        xticklabels=[],
    )
    plot_spike_train(
        sim_result.all_incoming_spikes,
        bounds,
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
        xlim=bounds,
    )
    axes["VI_sig"].plot(
        zoom.time,
        sim_result.VI_signal[zoom.i_slice] / mV,
    )
    axes["VI_sig"].plot(
        sim_result.VI_signal.slice(t_start, duration).time,
        sim_result.VI_signal.slice(t_start, duration) / mV,
    )
    axes["VI_sig"].set(
        xlabel="Time (s)",
        ylabel="VI signal",
        xlim=bounds,
    )
    axes["g_syn"].plot(
        zoom.time,
        sim_result.g_syn[zoom.i_slice] / nS,
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
