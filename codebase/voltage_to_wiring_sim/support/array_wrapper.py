from __future__ import annotations

import dataclasses
from dataclasses import dataclass
from functools import wraps

import numpy as np


@dataclass
class NDArrayWrapper(np.lib.mixins.NDArrayOperatorsMixin):

    # See "Writing custom array containers" from the NumPy manual:
    # https://numpy.org/doc/stable/user/basics.dispatch.html

    data: np.ndarray

    def __array__(self, dtype=None):
        # `dtype` argument is used when plotting an NDArrayWrapper with matplotlib.
        if dtype is None:
            return self.data
        else:
            return self.data.astype(dtype)

    @property
    def shape(self):
        return self.data.shape

    @property
    def ndim(self):
        return self.data.ndim

    @property
    def size(self):
        return self.data.size

    def __array_ufunc__(self, ufunc, _method, *inputs, **kwargs):
        np_result = ufunc(*(np.asarray(arg) for arg in inputs), **kwargs)
        new_wrapper = self._create_derived_instance(new_data=np_result)
        return new_wrapper

    def __array_function__(self, function, _types, args, kwargs):
        np_result = function(*(np.asarray(arg) for arg in args), **kwargs)
        new_wrapper = self._create_derived_instance(new_data=np_result)
        return new_wrapper

    def __getitem__(self, index):
        data_slice = self.data[index]
        new_wrapper = self._create_derived_instance(new_data=data_slice)
        return new_wrapper

    def __setitem__(self, index, value):
        self.data[index] = np.asarray(value)
        
    def _create_derived_instance(self, new_data: np.ndarray) -> NDArrayWrapper:
        """
        Create an instance of this object's class with different `data` but otherwise
        the same property values. `NDArrayWrapper` subclasses which do not store all
        their properties via the dataclass mechanism should reimplement this method.
        """
        properties = dataclasses.asdict(self)
        properties.update(data=new_data)
        return self.__class__(**properties)


def strip_NDArrayWrapper_inputs(function):
    @wraps(function)
    def wrapped_function(*args, **kwargs):
        stripped_args = (
            arg.data if isinstance(arg, NDArrayWrapper) else arg for arg in args
        )
        stripped_kwargs = {
            kw: arg.data if isinstance(arg, NDArrayWrapper) else arg
            for kw, arg in kwargs.items()
        }
        output = function(*stripped_args, **stripped_kwargs)
        return output

    return wrapped_function
