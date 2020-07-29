from copy import copy

import matplotlib as mpl


def figsize(
    aspect: float = 0.62, width: int = 500, rel_text_size: float = 1.33,
):
    """
    :return: A dictionary with keys "figsize" and "dpi" that can be passed as **kwargs
             to matplotlib figure creation methods.

    :param aspect:  Fig height / fig width.
    :param width:  Pixel width of figure.
    :param rel_text_size:  Determines how large text is relative to other plot elements,
                such as lines and ticks. (It is scaled so that it is "1" at the default
                dpi of 72).
    """
    dpi = 72 * rel_text_size  # = pixels per inch
    height = round(width * aspect)
    return dict(figsize=(width / dpi, height / dpi), dpi=dpi)


default_figsize = figsize()


# fmt: off

layout = {
    "figure.autolayout": False,   # Auto-apply `tight_layout`. (This doesn't seem to do
                                 # anything yet for the current simple plots).
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.facecolor": "white", # Avoid transparent background that make axis and tick
                                 # labels unreadable in a lot of image viewers (you
                                 # often see this when a matplotlib figure is eg shared
                                 # on Twitter).
    "xtick.color": "grey",
    "ytick.color": "grey",
}

sizing = {
    "figure.figsize": default_figsize["figsize"],
    "figure.dpi": default_figsize["dpi"],
    "xtick.labelsize": "small",     # Default is "medium"
    "ytick.labelsize": "small",
    "legend.fontsize": "small",     # Default is "medium"
    "xtick.major.size": 5,          # Default is 3.5
    "ytick.major.size": 5,
}

new_style = {**layout, **sizing}

# This is not the same as mpl.rcParamsDefault, as in a Jupyter Notebook, "backend" is eg
# changed to "module://ipykernel.pylab.backend_inline" in mpl.rcParams.
original_rcParams = copy(mpl.rcParams)

def reset_and_apply():
    # Reset base style before applying new style, so we can interactively experiment
    # with changing the new style (without this reset, we can't experiment with
    # reverting previously set properties).
    mpl.rcParams.update(original_rcParams)
    mpl.rcParams.update(new_style)

reset_and_apply()
