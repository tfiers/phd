
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
    "grid.linewidth"       : 0.5,        # These are for major grid;
    "grid.color"           : "#E7E7E7",  # minor grid styling is set in `sett`.

    "xtick.direction"      : "in",
    "ytick.direction"      : "in",
    "xtick.labelsize"      : "small", # Default is "medium"
    "ytick.labelsize"      : "small", # idem
    "legend.fontsize"      : "small", # Default is "medium"
    "axes.titlesize"       : "medium",
    "axes.labelsize"       : 9,
    "xaxis.labellocation"  : "center",
    "axes.titlelocation"   : "center",

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

def savefig_thesis(name, fig=None):
    if fig is None:
        if len(plt.get_fignums()) == 0:
            print("No figure in gcf. Supply one as 2nd arg")
            return
        fig = plt.gcf()
    path = f"../thesis/figs/{name}.pdf"
    fig.savefig(path)
    print(f"Saved at `{path}`")

def plot(*args, ax = None, **kw):
    if ax is None:
        _, ax = plt.subplots()
        # Alternative: `ax = plt.gca()`
    plotkw = {k: v for (k, v) in kw.items()
              if hasattr(mpl.lines.Line2D, f"set_{k}")}
    otherkw = {k: v for (k, v) in kw.items() if not k in plotkw}
    ax.plot(*args, **plotkw)
    sett(ax, **otherkw)
    return ax

def sett(
        ax,
        nbins_x = 7,
        nbins_y = 7,
        xticklabels = None,
        yticklabels = None,
        xunit = None,
        yunit = None,
        xaxloc = "bottom",
        yaxloc = "left",
        **kw
    ):
    "Set axes properties and apply a pretty default style"

    if yaxloc == "right":
        ax.yaxis.tick_right()
        ax.spines["left"].set_visible(False)
        ax.spines["right"].set_visible(True)
        ax.tick_params(left=False, right=True)

    if xaxloc == "top":
        ax.xaxis.tick_top()
        ax.spines["bottom"].set_visible(False)
        ax.spines["top"].set_visible(True)
        ax.tick_params(bottom=False, top=True)

    for k, v in kw.items():
        f = getattr(ax, f"set_{k}", None)
        if f is not None:
            f(v)

    # -- Various defaults that can't be set through rcParams --

    ax.grid(axis = "both", which = "minor", color = "#F4F4F4", linewidth = 0.44)

    for pos in ("left", "right", "bottom", "top"):
        spine = ax.spines[pos]
        if spine.get_visible():
            spine.set_position(("outward", 10))
            # - `Spine.set_position` resets ticks, and in doing so removes text
            #   properties. Hence these must be called before `set_ticks` below.
            # - This takes quite some time in profiling (still less than `plt.subplots`,
            #   though).

    set_ticks(
        ax,
        [nbins_x, nbins_y],
        [xticklabels, yticklabels],
        [xunit, yunit],
    )

def set_ticks(ax, nbins, ticklabels, units):
    "Opiniated tick defaults"
    xypairs = zip([ax.xaxis, ax.yaxis], nbins, ticklabels, units)
    for axis, nbins, ticklabels, unit in xypairs:
        loc = mpl.ticker.MaxNLocator(nbins = nbins, steps = [1, 2, 5, 10])
        #   `nbins` should probably depend on figure size, i.e. how large texts are wrt
        #   other graphical elements.
        #   For `steps` we omit 2.5.
        axis.set_major_locator(loc)
        axis.set_minor_locator(mpl.ticker.AutoMinorLocator())

        ticklocs = axis.get_ticklocs()
        # When setting custom lims, the auto locator will have ticklocs outside these
        # lims. If we would not trim the ticklocs, we'd not respect the custom lims.
        a, b = axis.get_view_interval()
        in_lims = (a <= ticklocs) & (ticklocs <= b)
        ticklocs = ticklocs[in_lims]

        if ticklabels is None:
            ticklabels = [f"{t:.4g}" for t in ticklocs]
        if unit is not None:
            suffix = f" {unit}"
            if axis == ax.xaxis:
                prefix_width = int(round(len(suffix) * 1.6))
                prefix = " " * prefix_width
                # Imprecise hack to shift label to the right, to get number back under
                # tick.
            else:
                prefix = ""
            ticklabels[-1] = prefix + ticklabels[-1] + suffix
        axis.set_ticks(ticklocs, ticklabels)
        # Note that this changes the tick locator to a FixedLocator. As a result,
        # changing the lims (e.g. zooming in) after this, you won't get useful ticks.
        # (Cannot replace by just `axis.set_ticklabels` either: then labels get out of
        # sync with ticks) Solution is to call `set` again, to get good ticks again.

def rm_ticks_and_spine(ax, where="bottom"):
    # You could also go `ax.xaxis.set_visible(False)`;
    # but that removes gridlines too. This keeps 'em.
    ax.spines[where].set_visible(False)
    ax.tick_params(which="both", **{where: False})
    if where in ("bottom", "top"):
        ax.set_xlabel(None)
    else:
        ax.set_ylabel(None)

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
