"""
Pipeline combining the sim/ and conntest/ packages.
"""
from __future__ import annotations

from dataclasses import dataclass
from functools import partial
from typing import Any

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from matplotlib.axes import Axes
from matplotlib.figure import Figure
from nptyping import NDArray

from .conntest.classification import Classification, plot_ROC, plot_classifications
from .conntest.permutation_test import (
    ConnectionTestData,
    ConnectionTestSummary,
    plot_STA_heights,
    plot_STAs,
    test_connection,
)
from .sim.imaging import add_VI_noise
from .sim.izhikevich_neuron import IzhikevichOutput, simulate_izh_neuron
from .sim.neuron_params import IzhikevichParams
from .sim.poisson_spikes import generate_Poisson_spikes
from .sim.synapses import calc_synaptic_conductance
from .support import Signal, cache_to_disk, fix_rng_seed, plot_signal, to_bounds
from .support.plot_util import figsize, new_plot_if_None, subplots
from .support.printing import with_progress_meter
from .support.spike_train import SpikeTimes, plot_spike_train
from .support.units import Quantity, mV, ms, nS


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
    rng_seed: int = None


@cache_to_disk
def simulate(params: N_to_1_SimParams) -> N_to_1_SimData:

    if params.rng_seed is not None:
        fix_rng_seed(params.rng_seed)

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


@cache_to_disk
def test_connections(sim_data: N_to_1_SimData, inline_meter=False):
    test_data = []
    test_summaries = []
    if inline_meter:
        meter = partial(with_progress_meter, end=" ")
    else:
        meter = partial(with_progress_meter, description="Testing connections")
    for spike_train in meter(sim_data.spike_trains):
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


def pass_df(seaborn_f, x=None, y=None, hue=None, **kwargs):
    # Seaborn requires pandas DataFrames as input (passing simple vectors seems at first
    # to be supported, but results in stupid bugs, e.g. `stack="multiple"` does not work
    # for `sns.histplot(x=vector_A, hue=vector_B)`).
    # This function abstracts the boilerplate of creating such dataframes. (I don't like
    # working with pandas DataFrames, as they offer no autocompletion on column names.
    # So I avoid them as much as possible).
    df = pd.DataFrame({"a": x, "b": y, "c": hue})
    ax = seaborn_f(data=df, x="a", y="b", hue="c", **kwargs)
    # Remove "a", "b", "c" labels.
    ax.set(xlabel=None, ylabel=None)
    ax.legend_.set_title(None)
    return ax


def plot_p_values(
    test_summaries: list[ConnectionTestSummary],
    sim_data: N_to_1_SimData,
    ax: Axes = None,
):
    p_values = [summary.p_value for summary in test_summaries]
    ax = new_plot_if_None(ax, **figsize(aspect=3))
    pass_df(
        sns.histplot,
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
    ax = new_plot_if_None(ax, **figsize(aspect=3))
    pass_df(
        sns.histplot,
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


def plot_conntest(
    test_data: list[ConnectionTestData],
    test_summaries: list[ConnectionTestSummary],
    sim_data: N_to_1_SimData,
):
    selected_spike_train = get_index_of_first_connected_train(sim_data)
    fig1, (fig1_ax_left, fig1_ax_right) = subplots(
        ncols=2, **figsize(aspect=3, width=800)
    )
    plot_STAs(test_data[selected_spike_train], fig1_ax_left)
    plot_STA_heights(test_data[selected_spike_train], fig1_ax_right)
    title_kwargs = dict(ha="left", va="baseline")
    fig1.suptitle(
        f"Spike train #{selected_spike_train}", x=0.06, y=0.97, **title_kwargs
    )

    fig2, (fig2_ax_left, fig2_ax_right) = subplots(
        ncols=2, **figsize(aspect=5, width=800)
    )
    plot_p_values(test_summaries, sim_data, fig2_ax_left)
    plot_relative_STA_heights(test_summaries, sim_data, fig2_ax_right)
    fig2_ax_right.legend_.remove()
    fig2.suptitle("All spike trains", x=0.08, y=1, **title_kwargs)


def plot_classifications_with_ROC(classifications: list[Classification]):
    fig, (left_ax, right_ax) = subplots(
        ncols=2, **figsize(aspect=3, width=800), gridspec_kw=dict(width_ratios=[2, 1])
    )
    plot_classifications(classifications, left_ax)
    plot_ROC(classifications, right_ax)
    left_ax.set_ylabel("Spike train #")
