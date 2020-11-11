from typing import Union

from mpl_toolkits.axes_grid1.anchored_artists import AnchoredSizeBar

from .units import Quantity


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