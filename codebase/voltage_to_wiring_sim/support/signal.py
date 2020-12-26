from dataclasses import dataclass

from .units import Quantity
from .array_wrapper import NDArrayWrapper


@dataclass
class Signal(NDArrayWrapper):
    """
    A NumPy array representing time series data. More precisely, a wrapper around a
    NumPy `ndarray`, with knowledge about the signal's timestep / sampling frequency,
    and providing related utility methods.

    The raw NumPy ndarray is found in the `.data` attribute.
    """

    timestep: Quantity
