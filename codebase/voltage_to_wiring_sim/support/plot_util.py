import functools
from typing import Optional, Sequence, Tuple, Union

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.axes import Axes
from matplotlib.figure import Figure
from matplotlib.transforms import ScaledTranslation


def figsize(
    aspect: float = 1.6,
    width: int = 500,
    rel_text_size: float = 1.33,
):
    """
    :param aspect:  Fig width / fig height.
    :param width:  Pixel width of figure.
    :param rel_text_size:  Determines how large text is relative to other plot elements,
                such as lines and ticks. (It is scaled so that it is "1" at the default
                dpi of 72).

    :return: A dictionary with keys "figsize" and "dpi" that can be passed as **kwargs
             to matplotlib figure creation methods.
    """
    dpi = 72 * rel_text_size  # = pixels per inch
    height = round(width / aspect)
    return dict(figsize=(width / dpi, height / dpi), dpi=dpi)


def horizontal_ylabel(
    ax: Axes, text: str, dx=-6, dy=-2, ha="right", x=0, y=1, bg_pad=0.4, **text_kwargs
):
    """dx and dy are in points, i.e. 1/72th of an inch."""
    offset = ScaledTranslation(dx / 72, dy / 72, ax.figure.dpi_scale_trans)
    bbox = dict(fc=ax.get_facecolor(), ec="none", boxstyle=f"square,pad={bg_pad}")
    kwargs = dict(ha=ha, va="top", bbox=bbox, transform=ax.transAxes + offset)
    return ax.text(x, y, text, **(kwargs | text_kwargs))


def ylabel_inside(
    ax: Axes,
    text: str,
    ylim_shift=12,
    dx=6,
    dy=0,
    x=0,
    y=1,
    ha="left",
    bg_pad=0.4,
    **text_kwargs,
):
    """ylim_shift: by how many points (1/72th of an inch) to move up the top ylimit."""
    y_lo, y_hi = ax.get_ylim()
    # We need to get ylims before calling `transData`. ylim are computed lazily.
    # See eg. https://github.com/matplotlib/matplotlib/issues/18220#issuecomment-672293833
    ylim_shift_inch = ylim_shift / 72
    pixels_per_inch = ax.figure.dpi
    ylim_shift_px = ylim_shift_inch * pixels_per_inch
    px_to_data = ax.transData.inverted()
    M = px_to_data.transform([(0, 0), (0, ylim_shift_px)])
    ylim_shift_data = np.diff(M[:, 1])[0]
    ax.set_ylim(y_lo, y_hi + ylim_shift_data)
    return horizontal_ylabel(ax, text, dx, dy, ha, x, y, bg_pad, **text_kwargs)


def add_reordered_legend(ax: Axes, order: tuple[int], **kwargs):
    h, l = ax.get_legend_handles_labels()
    ax.legend([h[i] for i in order], [l[i] for i in order], **kwargs)


# Add return types to plt.subplots (for autocompletion in IDE).

OneOrMoreAxes = Union[Axes, Sequence[Axes]]


def subplots(**kwargs) -> Tuple[Figure, OneOrMoreAxes]:
    return plt.subplots(**kwargs)


functools.update_wrapper(subplots, plt.subplots)


def new_plot_if_None(ax: Optional[Axes], **subplots_kwargs):
    if ax is None:
        _, ax = subplots(**subplots_kwargs)
    return ax
