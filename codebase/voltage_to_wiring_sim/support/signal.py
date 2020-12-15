from dataclasses import dataclass

import numpy as np

from .units import Quantity


@dataclass
class NDArrayWrapper(np.lib.mixins.NDArrayOperatorsMixin):

    data: np.ndarray

    def __array__(self):
        return self.data

    @property
    def shape(self):
        return self.data.shape

    @property
    def ndim(self):
        return self.data.ndim

    @property
    def size(self):
        return self.data.size


@dataclass
class Signal(NDArrayWrapper):
    """
    A NumPy array representing time series data. More precisely, a wrapper around a
    NumPy `ndarray`, with knowledge about the signal's timestep / sampling frequency,
    and providing related utility methods.

    The raw NumPy ndarray is found in the `.data` attribute.
    """

    data: np.ndarray
    timestep: Quantity

    def __array_ufunc__(
        self, ufunc: np.ufunc, _method: str, *inputs, **kwargs
    ) -> "Signal":
        input_arrays = map(np.asarray, inputs)
        np_result = ufunc(*input_arrays, **kwargs)
        result = Signal(np_result, self.timestep)
        return result

    def __array_function__(self, function, _types, args, kwargs):
        input_arrays = map(np.asarray, args)
        np_result = function(*input_arrays, **kwargs)
        result = Signal(np_result, self.timestep)
        return result
