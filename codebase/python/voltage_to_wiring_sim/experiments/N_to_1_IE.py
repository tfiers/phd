from dataclasses import dataclass

import numpy as np
from numpy import ndarray

from .. import (
    add_VI_noise,
    calc_synaptic_conductance,
    fix_rng_seed,
    generate_Poisson_spikes,
    simulate_izh_neuron,
)
from ..conntest.classification import apply_threshold
from ..conntest.classification_IE import (
    calc_AUCs,
    evaluate_classification,
    sweep_threshold,
)
from ..conntest.permutation_test import (
    ConnectionTestData,
    ConnectionTestSummary,
    test_connection,
)
from ..sim.izhikevich_neuron import IzhikevichOutput
from ..sim.neuron_params import IzhikevichParams, cortical_RS
from ..support import Signal
from ..support.misc import fill_dataclass, indices_where, round_stochastically
from ..support.printing import with_progress_meter
from ..support.units import Hz, Quantity, mV, minute, ms, nS


@dataclass
class Params:

    sim_duration: Quantity = 10 * minute
    timestep: Quantity = 0.1 * ms
    τ_syn: Quantity = 7 * ms
    neuron_params: IzhikevichParams = cortical_RS
    imaging_spike_SNR: Quantity = 20
    window_duration: Quantity = 100 * ms
    
    num_spike_trains: int = 30
    p_inhibitory: float = 0.2
    p_connected: float = 0.7
    spike_rate: Quantity = 20 * Hz

    Δg_syn_exc: Quantity = 0.4 * nS
    Δg_syn_inh: Quantity = 1.6 * nS

    v_syn_exc: Quantity = 0 * mV
    v_syn_inh: Quantity = -65 * mV

    rng_seed: int = 0


def simulate(p: Params):

    # ___ 1. Spike trains ___

    if p.rng_seed is not None:
        fix_rng_seed(p.rng_seed)

    input_spike_trains = np.empty(p.num_spike_trains, dtype=object)

    for i in range(p.num_spike_trains):
        input_spike_trains[i] = generate_Poisson_spikes(p.spike_rate, p.sim_duration)

    is_connected = np.array([False] * p.num_spike_trains)
    is_inhibitory = np.array([False] * p.num_spike_trains)
    #  Assumption: if not I then E, i.e. only two choices.

    num_inh = round_stochastically(p.p_inhibitory * p.num_spike_trains)
    num_exc = p.num_spike_trains - num_inh
    num_inh_conn = round_stochastically(p.p_connected * num_inh)
    num_exc_conn = round_stochastically(p.p_connected * num_exc)
    for i in range(p.num_spike_trains):
        if i < num_inh:
            is_inhibitory[i] = True
            if i < num_inh_conn:
                is_connected[i] = True
        else:
            if i < num_inh + num_exc_conn:
                is_connected[i] = True

    is_excitatory = ~is_inhibitory

    #
    # ___ 2.Synaptic conductance, Izhikevich sim, VI noise ___

    g_syns = []
    for i in indices_where(is_connected):
        Δg_syn = p.Δg_syn_exc if is_excitatory[i] else p.Δg_syn_inh
        g_syn = calc_synaptic_conductance(
            p.sim_duration, p.timestep, input_spike_trains[i], Δg_syn, p.τ_syn
        )
        g_syns.append(g_syn)

    v_syn = np.array([p.v_syn_inh if is_inh else p.v_syn_exc for is_inh in is_inhibitory])
    v_syn_connected = v_syn[indices_where(is_connected)]

    izh_output = simulate_izh_neuron(
        p.sim_duration, p.timestep, p.neuron_params, v_syn_connected, g_syns
    )

    VI_signal = add_VI_noise(izh_output.V_m, p.neuron_params, p.imaging_spike_SNR)

    return fill_dataclass(SimData, locals())


@dataclass
class SimData:
    num_inh: int
    num_exc: int
    num_inh_conn: int
    num_exc_conn: int
    input_spike_trains: ndarray
    is_connected: ndarray
    is_inhibitory: ndarray
    is_excitatory: ndarray
    g_syns: list[Signal]
    v_syn: ndarray
    izh_output: IzhikevichOutput
    VI_signal: Signal


def test_connections(
    d: SimData, p: Params
) -> tuple[(list[ConnectionTestData], list[ConnectionTestSummary])]:

    test_data = []
    test_summaries = []

    for i in with_progress_meter(range(p.num_spike_trains)):
        data, summary = test_connection(
            d.input_spike_trains[i], d.VI_signal, p.window_duration, num_shuffles=100
        )
        test_data.append(data)
        test_summaries.append(summary)

    return test_data, test_summaries


# Not cached by default, as output is large.
def simulate_and_test_connections(p: Params):
    sim_data = simulate(p)
    test_data, test_summaries = test_connections(sim_data, p)
    return sim_data, test_data, test_summaries


def eval_performance(sim_data, test_summaries):

    # Eval at fixed p_value threshold
    is_classified_as_connected = apply_threshold(test_summaries, p_value_threshold=0.05)
    evalu_p_0_05 = evaluate_classification(
        is_classified_as_connected, sim_data.is_connected, sim_data.is_inhibitory
    )

    # Eval at all p_value thresholds
    thr_sweep = sweep_threshold(
        test_summaries, sim_data.is_connected, sim_data.is_inhibitory
    )
    AUC, AUC_exc, AUC_inh = calc_AUCs(thr_sweep)

    return evalu_p_0_05, thr_sweep, AUC, AUC_exc, AUC_inh
