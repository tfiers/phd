import matplotlib.pyplot as plt
import numpy as np

from .input_spike_trains import generate_Poisson_spikes
from ..support import Signal, compile_to_machine_code, to_num_timesteps
from ..support.spike_train import SpikeTimes, to_indices
from ..support.units import Hz, Quantity, ms, nS


def calc_synaptic_conductance(
    sim_duration: Quantity,
    timestep: Quantity,
    spike_times: SpikeTimes,
    Δg_syn: Quantity,
    τ_syn: Quantity,
    pure_python=False,
) -> Signal:
    """
    :param Δg_syn:  Increase in synaptic conductance per spike.
    :param τ_syn:  Synaptic conductance decay time constant.
    :return:  Array of length N, `g_syn`
    """
    num_timesteps = to_num_timesteps(sim_duration, timestep)
    g_syn = np.empty(num_timesteps) * nS
    # g_syn.name = "Synaptic conductance"
    sorted_spike_times = np.sort(spike_times)
    spike_indices = to_indices(sorted_spike_times, timestep)
    #   (We don't put this in the compiled function as np.round(x) won't work yet with
    #   Numba without the `out=` argument. https://github.com/numba/numba/issues/4439).
    if pure_python:
        f = _calc_g_syn
    else:
        f = compile_to_machine_code(_calc_g_syn)
    f(g_syn, timestep, spike_indices, Δg_syn, τ_syn)
    return Signal(g_syn, timestep)


def _calc_g_syn(g_syn, dt, spike_indices, Δg_syn, τ_syn):
    num_spikes = len(spike_indices)
    num_processed_spikes = 0
    dgsyn_dt = lambda i: -g_syn[i] / τ_syn  # Exponential decay.
    for i in range(len(g_syn)):
        if i == 0:
            g_syn[i] = 0
        else:
            g_syn[i] = g_syn[i - 1] + dt * dgsyn_dt(i - 1)
        # Add conductance bump for every spike that falls within the current time bin i.
        while (
            num_processed_spikes < num_spikes
            and spike_indices[num_processed_spikes] == i
        ):
            g_syn[i] += Δg_syn
            num_processed_spikes += 1


def test():
    sim_duration = 300 * ms
    timestep = 0.1 * ms
    spikes = generate_Poisson_spikes(30 * Hz, sim_duration)
    Δg_syn = 2 * nS
    τ_syn = 7 * ms
    g_syn = calc_synaptic_conductance(
        sim_duration, timestep, spikes, Δg_syn, τ_syn, pure_python=True
    )
    plt.plot(g_syn.time / ms, g_syn)
    plt.xlabel("Time (ms)")
