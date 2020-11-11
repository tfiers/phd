from contextlib import contextmanager
from dataclasses import asdict, dataclass
from time import time
from typing import Sequence, Tuple, Union

import matplotlib.pyplot as plt
import numpy
from matplotlib.axes import Axes
from matplotlib.figure import Figure
from mpl_toolkits.axes_grid1.anchored_artists import AnchoredSizeBar

from .units import Quantity


@dataclass
class QuantityCollection:
    """ A collection of dimensioned values, with pretty printing ability. """

    def __str__(self):
        """ Invoked when calling `print()` on the dataclass. """
        subclass_name = self.__class__.__name__
        lines = [
            subclass_name,
            "-" * len(subclass_name),
        ]
        for name, value in asdict(self):
            lines.append(f"{name} = {str(value)}")
        return "\n".join(lines)


@contextmanager
def report_duration(action_description: str):
    print(action_description, end=" … ")
    t0 = time()
    yield
    duration = time() - t0
    print(f"✔ ({duration:.2g} s)")


def fix_rng_seed(seed=0):
    """
    Set seed of random number generator, to generate same random sequence in every
    script run, and thus get same results.
    """
    numpy.random.seed(seed)


# Add return types to plt.subplots (for autocompletion in IDE).
def subplots(**kwargs) -> Tuple[Figure, Union[Axes, Sequence[Axes]]]:
    return plt.subplots(**kwargs)


subplots.__doc__ = plt.subplots.__doc__


def add_scalebar(
    ax,
    length: Quantity,
    x: Union[float, Quantity] = 0.5,
    y: Union[float, Quantity] = 0.5,
    anchor="center",
    label_top=True,
    frame=False,
    pad=0.3,
    **kwargs,
):

    if isinstance(x, Quantity) and isinstance(y, Quantity):
        loc_transform = ax.transData
        x = x.display_data
        y = y.display_data
    elif isinstance(x, Quantity):
        loc_transform = ax.get_xaxis_transform()
        x = x.display_data
    elif isinstance(y, Quantity):
        loc_transform = ax.get_yaxis_transform()
        y = y.display_data
    else:
        loc_transform = ax.transAxes

    scalebar = AnchoredSizeBar(
        transform=ax.transData,
        size=length.value,
        label=str(length),
        loc=anchor,
        bbox_to_anchor=(x, y),
        bbox_transform=loc_transform,
        label_top=label_top,
        frameon=frame,
        pad=pad,
        **kwargs,
    )
    ax.add_artist(scalebar)
