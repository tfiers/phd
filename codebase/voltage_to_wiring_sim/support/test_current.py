import numpy as np

from .misc import indices_where, to_indices
from .units import ms


ix = to_indices


def add(val, t0, T, I, dt):
    ixs = ix([t0, t0 + T], dt)
    I[slice(*ixs)] += val


def add_δ(Q, t0, I, dt):
    T_δ = dt
    add(Q / T_δ, t0, T_δ, I, dt)


def add_pulse_with_decay(Q, t0, T, I, dt, τ=10 * ms):
    t = np.linspace(0, T, ix(T, dt), endpoint=False)
    pulse_with_decay = Q / τ * np.exp(-t / τ)
    # Integral of f = exp(-t/τ) is -f/τ, so area from 0 to ∞ is τ.
    add(pulse_with_decay, t0, T, I, dt)


def add_plateau(Q, t0, T, I, dt):
    add(Q / T, t0, T, I, dt)


def add_ramp(Q, t0, T, I, dt):
    t = np.linspace(0, T, ix(T, dt), endpoint=False)
    ramp = Q / T * 2 * t / T
    add(ramp, t0, T, I, dt)


def plot_test_current(ax, t, I, ylims, yδ=0.9):
    y_lo, y_hi = ylims
    ix_δ_up = indices_where(I > y_hi)
    ix_δ_down = indices_where(I < y_lo)
    I[ix_δ_up] = y_hi * yδ
    I[ix_δ_down] = y_lo * yδ
    ax.plot(t, I)
    ax.set_ylim(ylims)
    ax.plot(t[ix_δ_up], [y_hi * yδ] * ix_δ_up.size, "C0^", ms=5)
    ax.plot(t[ix_δ_down], [y_lo * yδ] * ix_δ_down.size, "C0v", ms=5)
