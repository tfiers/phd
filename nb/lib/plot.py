
print("importing mpl", end=" … ")
import matplotlib.pyplot as plt
print("✔")

print("importing brian", end=" … ")
from brian2.units import *
print("✔")

import matplotlib_inline
matplotlib_inline.backend_inline.set_matplotlib_formats('retina')

from plotbase import *


# Based on the memoir-class latex pdf in ../thesis/.
# In inches.
paperwidth = 8.3
marginwidth = mw = 0.28 * paperwidth  # From totex/Settings.tex → \marginwidth
maintextwidth = mtw = 324 / 72        # From latexmk output → Text width


def savefig_thesis(name, fig=None):
    if fig is None:
        if len(plt.get_fignums()) == 0:
            print("No figure in gcf. Supply one as 2nd arg")
            return
        fig = plt.gcf()
    path = f"../thesis/figs/{name}.pdf"
    fig.savefig(path)
    print(f"Saved at `{path}`")


def plotsig(
        y,
        ylabel = "",
        hylab = True,
        t_unit = ms,
        y_unit = 'auto',
        tlim = None,
        xlabel = 'Time',
        **kw
    ):
    if y_unit == 'auto':
        y_unit = max(abs(y)).get_best_unit()
    t = timesig(y)
    if tlim is None:
        t0, t1 = t[0], t[-1]
    else:
        t0, t1 = tlim
    shown = (t >= t0) & (t <= t1)
    x_ = t[shown] / t_unit
    y_ = y[shown] / y_unit
    ax = plot(x_, y_, xunit=t_unit, yunit=y_unit, **kw)
    if ylabel is not None:
        if hylab:
            hylabel(ax, ylabel)
        else:
            ax.set_ylabel(ylabel)
    ax.set_xlim([t0, t1] / t_unit)
    ax.set_xlabel(xlabel)
    return ax


def timesig(y, dt=0.1*ms, t0=0 * second):
    N = y.size
    T = N * dt
    return linspace(t0, t0+T, N)


def hylabel(ax, s, loc='left', dx=0, dy=4):
    """
    Add a horizontal ylabel
    """
    offset = mpl.transforms.ScaledTranslation(dx / 72, dy / 72, ax.figure.dpi_scale_trans)
    tf = ax.transAxes + offset
    fs = mpl.rcParams["axes.labelsize"]
    x = 0 if (loc == 'left') else 0.5 if (loc == 'center') else 1
    t = ax.text(x, 1, s, transform=tf, ha=loc, va="bottom", fontsize=fs)
    ax.hylabel = t


def add_hline(ax, y=0, c="black", lw=1):
    ax.axhline(y, 0, 1, c=c, lw=lw)
