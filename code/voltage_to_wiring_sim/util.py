from copy import copy
from dataclasses import Field, fields, is_dataclass
from functools import wraps
from numbers import Number
from typing import Union

import numpy as np
from unyt import unyt_array


def strip_input_units(original_function):
    """
    Converts dimensioned arguments to plain numbers in base SI units.
    
    Function decorator that
    1) scales inputs of type `unyt_quantity` or `unyt_array` to their base SI value
    ("mks" values, meter-kilogram-second), and
    2) converts them to simple NumPy arrays or plain Python scalars, thus stripping
    their units.
    This results in less overhead when the values are used in calculation, and thus a
    faster function.
    """

    @wraps(original_function)
    def modified_function(*args, **kwargs):
        args = (process(arg) for arg in args)
        kwargs = {key: process(arg) for key, arg in kwargs.items()}
        return original_function(*args, **kwargs)

    def process(value):
        if isinstance(value, unyt_array):
            # `unyt_quantity` is a subclass of `unyt_array`; so we will catch either.
            return strip_units(value)
        elif is_dataclass(value):
            new_dataclass = copy(value)
            for field in fields(new_dataclass):
                field: Field
                old_field_value = getattr(new_dataclass, field.name)
                new_field_value = process(old_field_value)  # recurse
                setattr(new_dataclass, field.name, new_field_value)
            return new_dataclass
        else:
            return value

    def strip_units(quantity: unyt_array) -> Union[np.ndarray, Number]:
        if not quantity.units.is_dimensionless:
            # Convert all units to common ground.
            quantity = quantity.in_base("mks")
            # `in_base` always returns a float datatype -- but for eg counts we want to
            # keep the integer datatype. Thus we don't call `in_base` for dimensionless
            # datatypes. (Dimensionless quantities needn't be converted anyway).
        # Get plain NumPy array, without units.
        value = quantity.value
        if value.ndim == 0:
            # Numba doesn't like zero-dimensional NumPy arrays. So convert those to
            # plain Python scalars.
            value = value.item()
        return value

    return modified_function
