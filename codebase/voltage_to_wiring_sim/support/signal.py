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
    t_start: Quantity = 0 * second

    @property
    def duration(self) -> Quantity:
        return self.size * self.timestep

    @property
    def time(self) -> Signal:
        data = np.linspace(
            *to_bounds(self.t_start, self.duration), num=self.size, endpoint=False
        )
        return Signal(data, self.timestep)

    def slice(self, t_start: Quantity, duration: Quantity) -> Signal:
        time_bounds = to_bounds(t_start, duration) - self.t_start
        index_bounds = np.round(time_bounds / self.timestep).astype(int)
        slice_data = self.data[slice(*index_bounds)]
        return Signal(slice_data, self.timestep, t_start)

    def _create_derived_object(self, new_data: np.ndarray) -> Union[Signal, np.number]:
        if new_data.size == 1:
            # Taking e.g. `max` or `mean` from a Signal, or slicing a single element from
            # it, should return a plain number, i.e. not something that contains timestep
            # info.
            return new_data
        elif new_data.size == self.size:
            return Signal(new_data, self.timestep, self.t_start)
        else:
            return Signal(new_data, self.timestep)


def to_bounds(t_start: Quantity, duration: Quantity) -> Array:
    return t_start + np.array([0, duration])


def to_num_timesteps(duration: Quantity, timestep: Quantity) -> int:
    return round(duration / timestep)


def plot_signal(signal: Signal, ax=None, time_units=second, **plot_kwargs):

    from ..support.plot_util import subplots

    if ax == None:
        _, ax = subplots()
    ax.plot(signal.time / time_units, signal, **plot_kwargs)
    return ax
