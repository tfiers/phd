from __future__ import annotations

from dataclasses import dataclass
from typing import Union

import numpy as np

from .array_wrapper import NDArrayWrapper
from .units import Array, Quantity


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
    def time(self) -> Signal:
        data = np.linspace(0, self.duration, num=self.size, endpoint=False)
        return Signal(data, self.timestep)

    def slice(self, t_start: Quantity, duration: Quantity) -> Signal:
        time_bounds = to_bounds(t_start, duration)
        index_bounds = np.round(time_bounds / self.timestep).astype(int)
        return self[slice(*index_bounds)]

    def _create_derived_object(self, new_data: np.ndarray) -> Union[Signal, np.number]:
        # Taking e.g. `max` or `mean` from a Signal, or slicing a single element from
        # it, returns a plain number, i.e. not something that contains timestep info.
        if new_data.size == 1:
            return new_data
        else:
            return super()._create_derived_object(new_data)


def to_bounds(t_start: Quantity, duration: Quantity) -> Array:
    return t_start + np.array([0, duration])


def to_num_timesteps(duration: Quantity, timestep: Quantity) -> int:
    return round(duration / timestep)
