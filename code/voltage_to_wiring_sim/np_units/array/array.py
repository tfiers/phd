# See `array.pyi` for additional typing information.

import numpy as np
from numpy.lib.mixins import NDArrayOperatorsMixin

from ..type_aliases import scalar_types
from ..unit import Unit, dimensionless


class UnitError(Exception):
    pass


def create_new_Array_or_Quantity(numeric_data):
    """
    Create either an new `Array` or a new `Quantity`, depending on the dimension of the
    given data.
    """
    from .quantity import Quantity

    if isinstance(numeric_data, scalar_types) or (
        isinstance(numeric_data, np.ndarray) and numeric_data.ndim == 0
    ):
        return object.__new__(Quantity)
    else:
        return object.__new__(Array)


class Array(NDArrayOperatorsMixin):
    """
    A NumPy array with a physical unit.

    This class is a wrapper around a NumPy `ndarray` (the `data` attribute), augmented
    with a `Unit` (the `display_unit` attribute). The data is stored -- and calculations
    with the data are done -- in the `base_unit` of this `display_unit`. The
    `display_unit` is only used at Array creation time and when printing the Array.
    """

    # See "Writing custom array containers"[1] from the NumPy manual for info on this
    # class's `__array_ufunc__` and `__array_function__` methods.
    #
    # `NDArrayOperatorsMixin` implements Python dunder methods like `__mul__` and
    # `__imul__` so that we can use standard Python syntax like `*` and `*=` with our
    # `Array`s. (`NDArrayOperatorsMixin` implements these by calling the corresponding
    # NumPy ufuncs [like `np.multiply`], which in turn defer to our `__array_ufunc__`
    # method).
    #
    # [1](https://numpy.org/doc/stable/user/basics.dispatch.html)
    #

    data: np.ndarray
    display_unit: Unit

    def __new__(cls, data, *args, **kwargs):
        # Note that `__new__`'s signature must match that of `__init__` (also in
        # `Quantity`).
        return create_new_Array_or_Quantity(data)

    def __init__(
        self,
        data,
        display_unit: Unit,
        data_are_given_in_display_units: bool = True,
    ):
        """
        :param data:  Array-like.
        :param display_unit:  Units in which to display the data.
        :param data_are_given_in_display_units:  If True (default), the given `data` is
                    taken to be expressed in `display_unit`s, and is converted to and
                    stored internally in `display_unit.base_unit`s. If False, `data`
                    is taken to be already expressed in `display_unit.base_unit`s,
                    and no conversion is done.
        """
        data_as_array = np.asarray(data)
        if not issubclass(data_as_array.dtype.type, np.number):
            raise TypeError(f'Input data must be numeric. Got "{repr(data_as_array)}"')
        if data_are_given_in_display_units:
            self.data = data_as_array * display_unit.conversion_factor
        else:
            self.data = data_as_array
        self.display_unit = display_unit

    @property
    def data_unit(self):
        return self.display_unit.base_unit

    @property
    def data_in_display_units(self) -> np.ndarray:
        return self.data / self.display_unit.conversion_factor

    dd: np.ndarray = data_in_display_units  # Shorthand

    #
    #
    # -------------------
    # Text representation

    def __str__(self):
        return format(self)

    def __format__(self, format_spec: str) -> str:
        # When no spec is given -- as is the case for `format(array)` and
        # `f"The answer is: {array}!"` -- Python calls this `__format__` method with
        # `format_spec = ""`
        if format_spec == "":
            format_spec = ".4G"
        array_string = np.array2string(
            self.data_in_display_units,
            formatter={"float_kind": lambda x: format(x, format_spec)},
        )
        return f"{array_string} {self.display_unit}"

    __repr__ = __str__

    #
    #
    # --------------------------------------------
    # Elementwise operations (+, >, cos, sign, ..)

    def __array_ufunc__(self, ufunc: np.ufunc, method: str, *inputs, **ufunc_kwargs):
        # - For unary operators (cos, sign, ..), `len(inputs)` is 1.
        # - For binary operators (+, >, ..), it is 2.
        # - `input[0] == self`.
        #   (So we could make `__array_ufunc__` a static method -- as we don't need the
        #   `self` first argument` -- but NumPy doesn't like that).
        if method != "__call__":
            # method == "reduce", "accumulate", ...
            raise NotImplementedError(
                f"`{self.__class__.__name__}` does not yet support "
                f'"{method}" ufuncs {self._DIY_help_text}'
            )
        if ufunc not in (np.add, np.subtract, np.multiply, np.divide):
            raise NotImplementedError(
                f"`{self.__class__.__name__}` does not yet support the NumPy ufunc "
                f"`{ufunc.__name__}` not yet supported. {self._DIY_help_text}"
            )
        other = inputs[1]
        if isinstance(other, Array):
            other_data = other.data
            other_display_unit = other.display_unit
        elif isinstance(other, Unit):
            if ufunc in (np.add, np.subtract):
                raise UnitError(
                    f"Cannot {ufunc.__name__} a `{Unit.__name__}` "
                    f"and a `{self.__class__.__name__}`."
                )
            other_display_unit = other
            other_data = other_display_unit.conversion_factor
        else:  # `other` is purely numeric (scalar or array-like)
            other_data = other
            other_display_unit = dimensionless
        new_display_unit = self._combine_units(other_display_unit, ufunc)
        if "out" in ufunc_kwargs:
            # This is an in-place operation (eg `array *= 2`). See
            # `numpy.lib.mixins._inplace_binary_method`, which added the `out` kwarg.
            ufunc(self.data, other_data, **ufunc_kwargs.update(out=self.data))
            self.display_unit = new_display_unit
        else:
            new_data: np.ndarray = ufunc(self.data, other_data, **ufunc_kwargs)
            if new_display_unit == dimensionless:
                if new_data.ndim == 0:
                    return new_data.item()
                else:
                    return new_data
            else:
                return self.__class__(new_data, new_display_unit, False)

    def _combine_units(self, other_display_unit: Unit, ufunc: np.ufunc) -> Unit:
        if ufunc in (np.add, np.subtract):
            if self.display_unit.base_unit != other_display_unit.base_unit:
                # 1*mV + (3*nS)
                raise UnitError(
                    f"Cannot {ufunc.__name__} incompatible units {self.display_unit} "
                    f"and {other_display_unit}."
                )
            # 1*mV + (3*volt)
            # Copy units from operand with largest units (nV + mV -> mV)
            if (
                self.display_unit.conversion_factor
                > other_display_unit.conversion_factor
            ):
                new_display_unit = self.display_unit
            else:
                new_display_unit = other_display_unit
        elif ufunc == np.multiply:
            # 1*mV * (3*nS)
            new_display_unit = self.display_unit * other_display_unit
        elif ufunc == np.divide:
            # 1*mV / (3*nS)
            new_display_unit = self.display_unit / other_display_unit
        return new_display_unit

    #
    #
    # ------------------------------
    # NumPy methods (mean, sum, ...)
    #

    def __array_function__(self, func, _types, _args, _kwargs):
        raise NotImplementedError(
            f"`{self.__class__.__name__}` does not yet support being used "
            f"with function `{func.__name__}`. {self._DIY_help_text}"
        )

    _DIY_help_text = (  # Shown when a NumPy operation is not implemented yet for our Array.
        "You can get the bare numeric data (a plain NumPy array) "
        "via `your_array.data`, and work with it manually."
    )
