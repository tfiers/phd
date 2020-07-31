from numba import jit
from numpy import empty

from .time_grid import TimeGrid
from .units import Array, Quantity, inputs_as_raw_data, nS


def calc_synaptic_conductance(
    time_grid: TimeGrid,
    spikes: Array,
    Δg_syn: Quantity,
    τ_syn: Quantity,
    numba: bool = False,
):
    """
    :param time_grid
    :param spikes:  Integer array of length N: # spikes in each timebin.
    :param Δg_syn:  Increase in synaptic conductance per spike.
    :param τ_syn:  Synaptic conductance decay time constant.
    :return:  Array of length N, `g_syn`
    """
    g_syn = empty(time_grid.N) * nS
    if numba:
        _calc_g_syn = inputs_as_raw_data(jit(_calc_g_syn))
    _calc_g_syn(g_syn, time_grid.dt, spikes, Δg_syn, τ_syn)
    return g_syn


def _calc_g_syn(g_syn, dt, spikes, Δg_syn, τ_syn):
    dgsyn_dt = lambda i: -g_syn[i] / τ_syn  # Exponential decay.
    for i in range(len(g_syn)):
        if i == 0:
            g_syn[i] = 0
        else:
            g_syn[i] = g_syn[i - 1] + dt * dgsyn_dt(i - 1)

        g_syn[i] += spikes[i] * Δg_syn
