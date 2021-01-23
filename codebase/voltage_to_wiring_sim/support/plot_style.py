from copy import copy

import matplotlib as mpl

from .plot_util import figsize


# fmt: off


paint = {
    "figure.autolayout": False,   # Auto-apply `tight_layout`. (This doesn't seem to do
                                 # anything yet for the current simple plots).
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.facecolor": "white", # Avoid transparent background that make axis and tick
                                 # labels unreadable in a lot of image viewers (you
                                 # often see this when a matplotlib figure is eg shared
                                 # on Twitter).
    "axes.grid": True,
    "grid.color": "0.85",  # Very light gray
    "axes.axisbelow": True,  # Grid below patches (like histogram bars), not on top.
    "ytick.left": False,  # No ticks, but still labels
    "xtick.bottom": False,
    "xtick.color": "0.4",
    "ytick.color": "0.4",
    "xtick.major.pad": 0.5,
    "ytick.major.pad": 0.5,
}


default_figsize = figsize()

sizing = {
    "figure.figsize": default_figsize["figsize"],
    "figure.dpi": default_figsize["dpi"],
    "xtick.labelsize": "small",     # Default is "medium"
    "ytick.labelsize": "small",
    "legend.fontsize": "small",     # Default is "medium"
}

new_style = {**paint, **sizing}

original_rcParams = copy(mpl.rcParams)
#   This is not the same as mpl.rcParamsDefault, as in a Jupyter Notebook, "backend" is
#   eg changed to "module://ipykernel.pylab.backend_inline" in mpl.rcParams.

def reset_and_apply():
    # Reset base style before applying new style, so we can interactively experiment
    # with changing the new style (without this reset, we can't experiment with
    # reverting previously set properties).
    mpl.rcParams.update(original_rcParams)
    mpl.rcParams.update(new_style)
