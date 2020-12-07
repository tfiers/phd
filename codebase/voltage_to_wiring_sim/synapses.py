import matplotlib.pyplot as plt
from numba import njit
from numpy import empty

from .spike_trains import generate_Poisson_spike_train
from .support.time_grid import TimeGrid
from .support.units import Array, Hz, Quantity, ms, nS, add_unit_support
from .support.signal import Signal


def calc_synaptic_conductance(
    time_grid: TimeGrid,
    spikes: Array,
    Δg_syn: Quantity,
    τ_syn: Quantity,
    calc_with_units: bool = False,
) -> Signal:
    """
    :param time_grid:  For how long and with which timestep do we simulate?
    :param spikes:  Integer array of length N: # spikes in each timebin.
    :param Δg_syn:  Increase in synaptic conductance per spike.
    :param τ_syn:  Synaptic conductance decay time constant.
    :return:  Array of length N, `g_syn`
    """
    g_syn = empty(time_grid.N) * nS
    # g_syn.name = "Synaptic conductance"
    if calc_with_units:
        f = _calc_g_syn
    else:
        f = add_unit_support(njit(_calc_g_syn, cache=True))
    f(g_syn, time_grid.dt, spikes, Δg_syn, τ_syn)
    return Signal(g_syn, time_grid.dt)


def _calc_g_syn(g_syn, dt, spikes, Δg_syn, τ_syn):
    dgsyn_dt = lambda i: -g_syn[i] / τ_syn  # Exponential decay.
    for i in range(len(g_syn)):
        if i == 0:
            g_syn[i] = 0
        else:
            g_syn[i] = g_syn[i - 1] + dt * dgsyn_dt(i - 1)

        g_syn[i] += spikes[i] * Δg_syn


def test():
    tg = TimeGrid(T=300 * ms, dt=0.1 * ms)
    spikes = generate_Poisson_spike_train(tg, f_spike=30 * Hz)
    Δg_syn = 2 * nS
    τ_syn = 7 * ms
    g_syn = calc_synaptic_conductance(tg, spikes, Δg_syn, τ_syn, calc_with_units=True)
    plt.plot(tg.t / ms, g_syn)
    plt.xlabel("Time (ms)")
