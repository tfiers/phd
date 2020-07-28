from dataclasses import dataclass, fields
from functools import wraps
from numbers import Number
from typing import Any, Dict, Union

from multipledispatch import dispatch
from numpy import ndarray
from toolz import valmap

from .unyt_mod import Array, Quantity


@dataclass
class QuantityCollection:
    """ A collection of dimensioned values, with pretty printing ability. """

    def __str__(self):
        """ Invoked when calling `print()` on the dataclass. """
        clsname = self.__class__.__name__
        lines = [clsname, "-" * len(clsname)]
        for name, value in self.asdict().items():
            lines.append(f"{name} = {str(value)}")
        return "\n".join(lines)

    def asdict(self) -> Dict[str, Union[Quantity, Array]]:
        """
        Faster version of dataclasses.asdict()
        That method makes a deepcopy of every field value, which in unyt's case calls
        slow sympy code.
        """
        return {field.name: getattr(self, field.name) for field in fields(self)}


#
# Call a different version of `as_raw_data()` depending on the input type.


@dispatch(Quantity)
def as_raw_data(quantity: Quantity) -> Number:
    return quantity.item()


@dispatch(Array)
def as_raw_data(array: Array) -> ndarray:
    """
    The returned array is a *view*, i.e. editing it will edit the original array.
    """
    return array.ndview


@dispatch(object)
def as_raw_data(value: Any) -> Any:
    return value


def inputs_as_raw_data(original_function):
    """ Function decorator that applies `as_raw_data` to all arguments. """

    @wraps(original_function)
    def modified_function(*args, **kwargs):
        return original_function(*map(as_raw_data, args), **valmap(as_raw_data, kwargs))

    return modified_function
