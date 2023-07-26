
import matplotlib_inline
matplotlib_inline.backend_inline.set_matplotlib_formats('retina')

from copy import copy
import matplotlib as mpl

style = {
    "axes.spines.top"      : False,
    "axes.spines.right"    : False,
    "axes.grid"            : True,
    "axes.axisbelow"       : True,  # Grid _below_ patches (such as histogram bars), not on top.
    "axes.grid.which"      : "both",
    "grid.linewidth"       : 0.5,        # These are for major grid. Minor grid styling
    "grid.color"           : "#E7E7E7",  # is set in `set!`.

    "xtick.direction"      : "in",
    "ytick.direction"      : "in",
    "xtick.labelsize"      : "small", # Default is "medium"
    "ytick.labelsize"      : "small", # idem
    "legend.fontsize"      : "small", # Default is "medium"
    "axes.titlesize"       : "medium",
    "axes.labelsize"       : 9,
    "xaxis.labellocation"  : "right",
    "axes.titlelocation"   : "right",

    "legend.borderpad"     : 0.6,
    "legend.borderaxespad" : 0.2,

    "lines.solid_capstyle" : "round",

    "figure.facecolor"     : "white",
    "figure.figsize"       : (4, 2.4),
    "figure.dpi"           : 150,
    "savefig.dpi"          : "figure",
    "savefig.bbox"         : "tight",

    "axes.autolimit_mode"  : "round_numbers",  # Default: "data"
    "axes.xmargin"         : 0,
    "axes.ymargin"         : 0,
}

original_rcParams = copy(mpl.rcParams)
#   This is not the same as mpl.rcParamsDefault, as in a Jupyter Notebook, "backend" is
#   eg changed to "module://ipykernel.pylab.backend_inline" in mpl.rcParams.

def reset_and_apply():
    # Reset base style before applying new style, so we can interactively experiment
    # with changing the new style (without this reset, we can't experiment with
    # reverting previously set properties).
    mpl.rcParams.update(original_rcParams)
    mpl.rcParams.update(style)

reset_and_apply()

from brian2 import *

def savefig_thesis(name):
    savefig(f"../thesis/figs/{name}.pdf")

def plotsig(
        y,
        ylabel = "",
        hylab = True,
        t_unit = ms,
        y_unit = 'auto',
        ax = None,
        tlim = None,
        **kw
    ):
    t = timesig(y)
    if y_unit == 'auto':
        y_unit = y.get_best_unit()
    if ax is None:
        _, ax = plt.subplots()
    if tlim is None:
        t0, t1 = t[0], t[1]
    else:
        t0, t1 = tlim
    shown = (t >= t0) & (t <= t1)
    plotkw = {k: v for (k, v) in kw.items()
              if hasattr(mpl.lines.Line2D, f"set_{k}")}
    otherkw = {k: v for (k, v) in kw.items() if not k in plotkw}
    ax.plot(t[shown] / t_unit, y[shown] / y_unit, **plotkw)
    if ylabel is not None:
        ylab = f"{ylabel} ({y_unit})"
        if hylab:
            hylabel(ax, ylab)
        else:
            ax.set_ylabel(ylab)
    ax.set_xlabel(f"Time ({t_unit})")
    ax.set(**otherkw)
    return ax

def timesig(y, dt=defaultclock.dt, t0=0 * second):
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
