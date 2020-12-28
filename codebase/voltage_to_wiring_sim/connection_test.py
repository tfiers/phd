from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from .STA import calculate_STA
from .spike_trains import shuffle
from .support import Signal
from .support.data_types import SpikeTimes
from .support.units import Array, Quantity


def test_connection(
    spike_train: SpikeTimes,
    VI_signal: Signal,
    window_duration: Quantity,
    num_shuffles: int,
) -> ConnectionTestResult:
    """
    Generate the data to test the following hypothesis:

        The neuron that generated `spike_train` is connected to the neuron from which
        `VI_signal` was recorded.

    (The null hypothesis is that they are NOT connected).

    Does this by looking for a postsynaptic potential in `VI_signal` through spike
    triggered averaging, both using the original `spike_train` and randomly shuffled
    versions of it.
    """

    shuffled_spike_trains = shuffle(spike_train, num_shuffles)

    def calc_STA_max(spike_train):
        STA_window = calculate_STA(VI_signal, spike_train, window_duration)
        return np.max(STA_window)

    original_train_STA_max = calc_STA_max(spike_train)
    shuffled_trains_STA_max = np.array(
        [calc_STA_max(train) for train in shuffled_spike_trains]
    )

    num_shuffled_train_STAs_larger = np.sum(
        shuffled_trains_STA_max > original_train_STA_max
    )
    if num_shuffled_train_STAs_larger == 0:
        p_value = 1 / num_shuffles
        p_value_type = PValueType.LIMIT
    else:
        p_value = num_shuffled_train_STAs_larger / num_shuffles
        p_value_type = PValueType.EQUAL

    mean_shuffled_STA_max = np.mean(shuffled_trains_STA_max)
    original_vs_shuffled_STA_max = original_train_STA_max / mean_shuffled_STA_max

    return ConnectionTestResult(
        shuffled_spike_trains,
        original_train_STA_max,
        shuffled_trains_STA_max,
        p_value,
        p_value_type,
        mean_shuffled_STA_max,
        original_vs_shuffled_STA_max,
    )


@dataclass
class ConnectionTestResult:
    shuffled_spike_trains: list[SpikeTimes]
    original_train_STA_max: Quantity
    #    Maximum height of STA window using original spike train.
    shuffled_trains_STA_max: Array
    #    Maximum heights of STA windows using shuffled spike trains.
    p_value: float  # p(H0 | data)
    p_value_type: PValueType
    mean_shuffled_STA_max: Quantity
    original_vs_shuffled_STA_max: float


class PValueType:
    LIMIT = "<"
    EQUAL = "="


def test():
    import voltage_to_wiring_sim as v
    from voltage_to_wiring_sim.support.units import second, ms, Hz, nS
    tg = v.TimeGrid(duration=1 * second, timestep=0.2 * ms)
    st = v.generate_Poisson_spikes(spike_rate=30 * Hz, simulation_duration=tg.duration)
    g_syn = v.calc_synaptic_conductance(tg, st, Δg_syn=0.9*nS, τ_syn=0.7*ms)
    sim = v.simulate_izh_neuron(tg, v.params.cortical_RS, g_syn)
    test_connection(st, sim.V_m, window_duration=80 * ms, num_shuffles=10)
