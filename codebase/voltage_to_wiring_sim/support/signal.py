from __future__ import annotations

from dataclasses import dataclass
from typing import Union

import numpy as np

from .array_wrapper import NDArrayWrapper
from .units import Array, Quantity, second


@dataclass
class Signal(NDArrayWrapper):
    """
    A NumPy array representing time series data. More precisely, a wrapper around a
    NumPy `ndarray`, with knowledge about the signal's timestep / sampling frequency,
    and providing related utility methods.

    The raw NumPy ndarray is found in the `.data` attribute.
    """

    timestep: Quantity

    @property
    def duration(self) -> Quantity:
        return self.size * self.timestep

    @property
    def time(self, start=0 * second) -> Array:
        return np.linspace(start, start + self.duration, num=self.size)

    def _create_derived_object(self, new_data: np.ndarray) -> Union[Signal, np.number]:
        # Taking e.g. `max` or `mean` from a Signal, or slicing a single element from
        # it, returns a plain number, i.e. not something that contains timestep info.
        if new_data.size == 1:
            return new_data
        else:
            return super()._create_derived_object(new_data)
