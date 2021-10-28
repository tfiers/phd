from dataclasses import dataclass

import numpy as np

from .. import (
    calc_synaptic_conductance,
    fix_rng_seed, generate_Poisson_spikes,
    simulate_izh_neuron,
    add_VI_noise,
)
from ..conntest.permutation_test import test_connection
from ..sim.neuron_params import IzhikevichParams, cortical_RS
from ..support import cache_to_disk
from ..support.units import Hz, Quantity, mV, minute, ms, nS


@dataclass
class Params:

    sim_duration: Quantity = 10 * minute
    timestep: Quantity = 0.1 * ms
    spike_rate: Quantity = 20 * Hz
    Δg_syn: Quantity = 0.8 * nS
    τ_syn: Quantity = 7 * ms
    neuron_params: IzhikevichParams = cortical_RS
    imaging_spike_SNR: Quantity = 20

    v_syn_E: Quantity = 0 * mV
    v_syn_I: Quantity = -70 * mV

    num_spike_trains: int = 30
    p_inhibitory: float = 0.6
    p_connected: float = 0.6
    spike_rate: Quantity = 20 * Hz

    window_duration: Quantity = 100 * ms
    
    rng_seed: int = None


@cache_to_disk
def simulate_and_test_connections(p: Params):

    # ___ 1. Spike trains ___
    
    if p.rng_seed is not None:
        fix_rng_seed(p.rng_seed)

    input_spike_trains = np.empty(p.num_spike_trains, dtype=object)
    
    for i in range(p.num_spike_trains):
        input_spike_trains[i] = generate_Poisson_spikes(p.spike_rate, p.sim_duration)
    
    is_connected = np.array([False] * p.num_spike_trains)
    is_inhibitory = np.array([False] * p.num_spike_trains)
    #  Assumption: if not I then E, i.e. only two choices.
    
    num_inh = round(p.p_inhibitory * p.num_spike_trains)
    num_exc = p.num_spike_trains - num_inh
    num_inh_conn = round(p.p_connected * num_inh)
    num_exc_conn = round(p.p_connected * num_exc)
    for i in range(p.num_spike_trains):
        if i < num_inh:
            is_inhibitory[i] = True
            if i < num_inh_conn:
                is_connected[i] = True
        else:
            if i < num_inh + num_exc_conn:
                is_connected[i] = True


    #
    # ___ 2.Synaptic conductance, Izhikevich sim, VI noise ___

    g_syns = []
    for i in indices_where(is_connected):
        g_syn = calc_synaptic_conductance(
            p.sim_duration, p.timestep, input_spike_trains[i], p.Δg_syn, p.τ_syn
        )
        g_syns.append(g_syn)

    v_syn = np.array([p.v_syn_I if is_inh else p.v_syn_E for is_inh in is_inhibitory])
    v_syn_connected = v_syn[indices_where(is_connected)]

    izh_output = simulate_izh_neuron(
        p.sim_duration, p.timestep, p.neuron_params, v_syn_connected, g_syns
    )

    VI_signal = add_VI_noise(izh_output.V_m, p.neuron_params, p.imaging_spike_SNR)

    #
    # ___ 3. Connection tests ___

    test_summaries = []

    for i in range(p.num_spike_trains):
        data, summary = test_connection(
            input_spike_trains[i], VI_signal, p.window_duration, num_shuffles=100
        )
        test_summaries.append(summary)
        print(".", end="")

    return is_connected, is_inhibitory, test_summaries


def indices_where(bool_array):
    return np.nonzero(bool_array)[0]
