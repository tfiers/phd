
import matplotlib.pyplot as plt
import matplotlib as mpl

from rcparams import *

def plot(*args, ax = None, fs = (4, 2.4), **kw):
    if ax is None:
        _, ax = plt.subplots(figsize=fs)
        # Alternative: `ax = plt.gca()`

    if "clip_on" not in kw:
        kw["clip_on"] = False

    plotkw = {k: v for (k, v) in kw.items()
              if hasattr(mpl.lines.Line2D, f"set_{k}")}
    otherkw = {k: v for (k, v) in kw.items() if not k in plotkw}
    ax.plot(*args, **plotkw)
    sett(ax, **otherkw)
    return ax

def sett(
        ax,
        xtype = "default",
        ytype = "default",
        nbins_x = 7,
        nbins_y = 7,
        xticklabels = None,
        yticklabels = None,
        xminorticks = True,
        yminorticks = True,
        xunit = None,
        yunit = None,
        xaxloc = "bottom",
        yaxloc = "left",
        **kw
    ):
    "Set axes properties and apply a pretty default style"

    # -- Axis location, spines, ticks, and gridlines --

    if xtype != "keep":
        if xaxloc == "top":
            ax.xaxis.tick_top()
        xticks_on = xtype not in ("categorical", "off")
        bottomticks_on = xticks_on and xaxloc == "bottom"
        topticks_on    = xticks_on and xaxloc == "top"
            # If `False`, no gridlines, spines, nor ticks. (But can still have ticklabels).
        ax.spines["bottom"].set_visible(bottomticks_on)
        ax.spines["top"   ].set_visible(topticks_on)
        ax.tick_params(bottom=bottomticks_on, top=topticks_on)
        ax.xaxis.grid(xticks_on)
        if xtype == "off":
            ax.xaxis.set_visible(False)
        if xtype == "fraction":
            ax.set_xlim(0, 1)

    if ytype != "keep":
        if yaxloc == "top":
            ax.yaxis.tick_right()
        yticks_on = ytype not in ("categorical", "off")
        leftticks_on = yticks_on and yaxloc == "left"
        rightticks_on    = yticks_on and yaxloc == "right"
        ax.spines["left" ].set_visible(leftticks_on)
        ax.spines["right"].set_visible(rightticks_on)
        ax.tick_params(left=leftticks_on, right=rightticks_on)
        ax.yaxis.grid(yticks_on)
        if ytype == "off":
            ax.yaxis.set_visible(False)
        if ytype == "fraction":
            ax.set_ylim(0, 1)

    # -- set_xlabel, etc --

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
        [xtype, ytype],
        [nbins_x, nbins_y],
        [xminorticks, yminorticks],
        [xticklabels, yticklabels],
        [xunit, yunit],
    )

def set_ticks(ax, axtypes, nbins, minorticks, ticklabels, units):
    "Opiniated tick defaults"
    xypairs = zip([ax.xaxis, ax.yaxis], axtypes, nbins, minorticks, ticklabels, units)
    for axis, axtype, nbins, minorticks, ticklabels, unit in xypairs:

        off = mpl.ticker.NullLocator()
        turn_off_minorticks = lambda: axis.set_minor_locator(off)

        if axtype == "pass":
            pass

        elif axtype == "range":
            # Because we set the rcParam `autolimit_mode` to `data`, xlim/ylim == data
            # range.
            a, b = axis.get_view_interval()
            digits = 2
            axis.set_ticks([round_(a, "down", digits), round(b, "up", digits)])
            # Turn off all gridlines.
            axis.grid(which = "major", visible = False)
            turn_off_minorticks()

        elif axtype == "categorical":
            # Do not mess with ticklocs. Except:
            turn_off_minorticks()

        if axis.get_scale() == "log":
            pass  # Mpl default is good, do nothing.

        else:
            loc = mpl.ticker.MaxNLocator(nbins = nbins, steps = [1, 2, 5, 10])
            #   `nbins` should probably depend on figure size, i.e. how large texts are
            #   wrt other graphical elements.
            #   For `steps` we omit 2.5.
            axis.set_major_locator(loc)
            if minorticks:
                axis.set_minor_locator(mpl.ticker.AutoMinorLocator())
            else:
                turn_off_minorticks()

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


from math import ceil, floor

def round_(x, mode="up", decimals=0):
    s = 10**decimals
    f = ceil if mode == "up" else floor
    return f(x * s) / s


def rm_ticks_and_spine(ax, where="bottom"):
    # You could also go `ax.xaxis.set_visible(False)`;
    # but that removes gridlines too. This keeps 'em.
    ax.spines[where].set_visible(False)
    ax.tick_params(which="both", **{where: False})
    if where in ("bottom", "top"):
        ax.set_xlabel(None)
        ax.set_xticklabels([])
    else:
        ax.set_ylabel(None)
        ax.set_yticklabels([])
