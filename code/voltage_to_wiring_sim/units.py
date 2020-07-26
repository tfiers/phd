from copy import copy
from dataclasses import Field, fields, is_dataclass, dataclass, asdict
from functools import wraps
from numbers import Number
from typing import Any, Union

import unyt
from multipledispatch import dispatch
from numpy import ndarray
from toolz import valmap


# Automatically add units and signal names to axes.
unyt.matplotlib_support()

from unyt import unyt_array, unyt_quantity, Unit

# This is slightly verbose. Shorter would be: `from unyt import pF, V, ..`. But alas
# this shorter version doesn't allow for auto-imports in PyCharm. (All these names are
# generated dynamically, so PyCharm can't find them).
pF = Unit("pF")
V = Unit("V")
mV = Unit("mV")
A = Unit("A")
pA = Unit("pA")
ms = Unit("ms")
s = Unit("s")
min = Unit("min")

try:
    unyt.define_unit("S", (1, "A/V"), prefixable=True)
except:
    # Siemens was already defined -- i.e. it's not the first time this script has run.
    pass

S = Unit("S")
nS = Unit("nS")


@dataclass
class QuantityCollection:
    """ A collection of dimensioned values, with pretty printing ability. """

    def __str__(self):
        """ Invoked when calling `print()` on the dataclass. """
        # `str()` shouldn't be necessary, but there's a bug in unyt that double-prints
        # the unit when using just the format string.
        lines = [f"{name} = {str(value)}" for name, value in asdict(self).items()]
        return "\n".join(lines)


# Call a different version of `strip_units()` depending on the input type.

# `unyt_quantity` is a subclass of `unyt_array`; so we will catch either with this
# dispatch command.
@dispatch(unyt_array)
def strip_units(quantity: Union[unyt_quantity, unyt_array]) -> Union[Number, ndarray]:
    """
    Converts the given quantity to base SI units (i.e. without prefix, e.g. "nA" to
    "A"), and removes the unit. The result is a plain Python scalar or NumPy array,
    which removes overhead when used in calculation, yielding a faster calculation.
    """

    if not quantity.units.is_dimensionless:
        # Convert all units to common ground. (mks = meter-kilogram-second).
        quantity = quantity.in_base("mks")
    # `in_base()` always returns a float datatype -- but for eg counts we want to
    # keep the integer datatype. Thus we don't call `in_base` for dimensionless
    # datatypes. (Dimensionless quantities needn't be converted anyway).

    # Get plain NumPy array, without units.
    value = quantity.value

    if value.ndim == 0:
        # Numba doesn't like zero-dimensional NumPy arrays. So convert those to
        # plain Python scalars.
        value = value.item()

    return value


@dispatch(QuantityCollection)
def strip_units(dataclass: QuantityCollection) -> QuantityCollection:
    new = copy(dataclass)
    for name, value in asdict(dataclass).items():
        setattr(new, name, strip_units(value))
    return new


@dispatch(object)
def strip_units(value: Any) -> Any:
    return value


def strip_input_units(original_function):
    """ Function decorator that applies `strip_unit` to all arguments. """

    @wraps(original_function)
    def modified_function(*args, **kwargs):
        return original_function(*map(strip_units, args), **valmap(strip_units, kwargs))

    return modified_function
