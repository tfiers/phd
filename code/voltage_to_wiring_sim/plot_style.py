from copy import copy
from dataclasses import dataclass

import matplotlib as mpl


@dataclass
class FigSizeCalc:
    text_vs_plot_size: float = 0.24
    fig_width_pixels: int = 500
    # `fig_width_pixels` is only approximate. Note also that 'retina display' in Jupyter
    # Notebooks will double it.
    fig_height_vs_width: float = 0.62

    def __post_init__(self):
        self.pixels_per_inch = 400 * self.text_vs_plot_size
        self.fig_height_pixels = round(self.fig_width_pixels * self.fig_height_vs_width)
        self.figsize = (
            self.fig_width_pixels // self.pixels_per_inch,
            self.fig_height_pixels // self.pixels_per_inch,
        )
        self.fig_kwargs = {
            "figsize": self.figsize,
            "dpi": self.pixels_per_inch,
        }


# fmt: off

layout = {
    "figure.autolayout": True,   # Auto-apply `tight_layout`. (This doesn't seem to do
                                 # anything yet for the current simple plots).
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.facecolor": "white", # Avoid transparent background that make axis and tick
                                 # labels unreadable in a lot of image viewers (you
                                 # often get this when a matplotlib figure is shared on
                                 # Twitter).
    "xtick.color": "grey",
    "ytick.color": "grey",
}



default_fig_size = FigSizeCalc()

sizing = {
    "figure.figsize": default_fig_size.figsize,
    "figure.dpi": default_fig_size.pixels_per_inch,
    "xtick.labelsize": "small",     # Default is "medium"
    "ytick.labelsize": "small",
    "legend.fontsize": "small",     # Default is "medium"
    "xtick.major.size": 5,          # Default is 3.5
    "ytick.major.size": 5,
}

new_style = {**layout, **sizing}

# This is not the same as mpl.rcParamsDefault in Jupyter Notebook
# ("backend" is eg changed to "module://ipykernel.pylab.backend_inline")
original_rcParams = copy(mpl.rcParams)

def reset_and_apply():
    # Reset base style before applying new style, so we can interactively experiment
    # with changing the new style (without this reset, we can't experiment with
    # reverting previously set properties).
    mpl.rcParams.update(original_rcParams)
    mpl.rcParams.update(new_style)

reset_and_apply()
