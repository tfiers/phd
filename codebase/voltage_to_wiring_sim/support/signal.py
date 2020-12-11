from dataclasses import dataclass

import numpy as np

from .units import Quantity


@dataclass
class Signal(np.lib.mixins.NDArrayOperatorsMixin):
    """
    A NumPy array representing time series data. More precisely, a wrapper around a
    NumPy `ndarray`, with knowledge about the signal's timestep / sampling frequency,
    and providing related utility methods.

    The raw NumPy ndarray is found in the `.data` attribute.
    """

    data: np.ndarray
    timestep: Quantity

    # See "Writing custom array containers"[1] from the NumPy manual for info on the
    # below `__array__`, `__array_ufunc__`, and `__array_function__` methods.
    #
    # # [1](https://numpy.org/doc/stable/user/basics.dispatch.html)

    # `Signal`'s base class `NDArrayOperatorsMixin` implements Python dunder methods
    # like `__mul__` and `__imul__`, so that we can use standard Python syntax like `*`
    # and `*=` with our `Signal`s.
    #
    # `NDArrayOperatorsMixin` implements these dunders by calling the corresponding
    # NumPy ufunc (like `np.multiply`), which in turn defer to our `__array_ufunc__`
    # method.

    def __array__(self):
        return self.data

    def __array_ufunc__(
        self, ufunc: np.ufunc, _method: str, *inputs, **kwargs
    ) -> "Signal":
        np_result = ufunc(*map(np.asarray, inputs), **kwargs)
        result = Signal(data=np_result, timestep=self.timestep)
        return result

    def __array_function__(self, function, _types, args, kwargs):
        np_result = function(*map(np.asarray, args), **kwargs)
        result = Signal(data=np_result, timestep=self.timestep)
        return result
