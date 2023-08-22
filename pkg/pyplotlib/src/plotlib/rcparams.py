
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
