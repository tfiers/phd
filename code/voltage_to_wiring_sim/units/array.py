from numpy import add, array2string, asarray, divide, multiply, ndarray, subtract

from .unit import Unit
from .ipython_integration import _make_ipython_print_str


_DIY_HELP_TEXT = (
    "You can get the raw, unitless data (a plain Numpy array) "
    "via `array.data_in_base_units` (or its shorthand `array.bd`), "
    "and operate on these. You can then create a new Array, with the result, "
    "a handmade `Unit`, and `data_are_in_base_units = True`."
)


class UnitError(Exception):
    pass


# See "Writing custom array containers" [1] from the Numpy manual for info on this
# class's `__array__`, `__array_ufunc__`, and `__array_function__` methods.
#
# [1](https://numpy.org/doc/stable/user/basics.dispatch.html)
#
class Array:

    data_in_base_units: ndarray
    display_unit: Unit
    base_unit: Unit

    def __init__(self, data, display_unit: Unit, data_are_in_base_units: bool = False):
        """
        :param data:  A scalar or array-like.
        :param display_unit:  Units in which to display the data.
        :param data_are_in_base_units:  If False (default), the given `data` is assumed
                    to be expressed in `unit`s, and is converted to and stored
                    internally in `unit.base_unit`s. If True, `data` is assumed to be
                    already expressed in `unit.base_unit`s, and no conversion is done.
        """
        self.display_unit = display_unit
        self.base_unit = display_unit.base_unit
        if data_are_in_base_units:
            self.data_in_base_units = asarray(data)
        else:
            self.data_in_base_units = asarray(data) * self.display_unit.factor

    @property
    def data_in_display_units(self) -> ndarray:
        return self.data_in_base_units / self.display_unit.factor

    #
    #
    # Shorthands

    dd = data_in_display_units

    @property
    def bd(self):
        return self.data_in_base_units

    #
    #
    # Text representation

    def __repr__(self):
        return (
            f"{self.__class__.__name__}"
            f'({self.data_in_display_units}, "{self.display_unit}")'
        )

    def __str__(self):
        return format(self)

    def __format__(self, format_spec: str) -> str:
        # When no spec is given in `format(x)` (or equivalently, in `f"{x}"`),
        # `format_spec` will be the empty string.
        if format_spec == "":
            format_spec = ".4G"
        arr_str = array2string(
            self.data_in_display_units,
            formatter={"float_kind": lambda x: format(x, format_spec)},
        )
        return f"{arr_str} {self.display_unit}"

    _repr_pretty_ = _make_ipython_print_str

    #
    #
    # Called by `np.asarray(arr)`.
    def __array__(self):
        if isinstance(self.data_in_base_units, ndarray):
            return self.data_in_base_units
        else:
            # `Array` was initialised with a scalar value.
            # (`self.data = asarray(value) * scalar` is then also a scalar).
            return asarray(self.data_in_base_units)

    #
    #
    # Elementwise operations (+, >, cos, sign, ..)
    #
    # - For unary operators (cos, sign, ..), `len(inputs)` is 1.
    # - For binary operators (+, >, ..), it is 2.
    # - `input[0] == self`. (But we can't make __array_ufunc__ a static method, for
    #   some reason).
    def __array_ufunc__(self, ufunc, method, *inputs, **kwargs):
        if method != "__call__":
            # method == "reduce", "accumulate", ...
            raise NotImplementedError(
                f'"{method}" ufuncs not yet supported. {_DIY_HELP_TEXT}'
            )
        if ufunc not in (add, subtract, multiply, divide):
            raise NotImplementedError(
                f"ufunc {ufunc.__name__} not yet supported. {_DIY_HELP_TEXT}"
            )
        _, other = inputs
        if isinstance(other, Array):
            other_arr = other
        elif isinstance(other, Unit):
            other_arr = 1 * other
        else:  # `other` is scalar or array_like
            other_arr = other * Unit("1")
        return self._combine_with_Array(other_arr, ufunc, kwargs)

    def _combine_with_Array(self, other_array: "Array", ufunc, ufunc_kwargs) -> "Array":
        if ufunc in (add, subtract):
            if self.base_unit != other_array.base_unit:
                # 1*mV + (3*nS)
                raise UnitError(
                    f"Cannot {ufunc.__name__} incompatible units {self.display_unit} "
                    f"and {other_array.display_unit}."
                )
            # 1*mV + (3*volt)
            # Copy units from operand with largest units (nV + mV -> mV)
            if self.display_unit.factor > other_array.display_unit.factor:
                new_display_unit = self.display_unit
            else:
                new_display_unit = other_array.display_unit
        elif ufunc == multiply:
            # 1*mV * (3*nS)
            new_display_unit = self.display_unit * other_array.display_unit
        elif ufunc == divide:
            # 1*mV / (3*nS)
            new_display_unit = self.display_unit / other_array.display_unit
        new_data = ufunc(
            self.data_in_base_units, other_array.data_in_base_units, **ufunc_kwargs
        )
        return Array(new_data, new_display_unit, data_are_in_base_units=True)

    #
    #
    # Implement syntax such as `arr1 + arr2`, `2 * array`, etc.
    # (The Numpy methods such as `multiply` and `add` that we forward to here will defer
    # to our `__array_ufunc__` method).
    # (`numpy.lib.mixins.NDArrayOperatorsMixin` could also do this for us, but then
    # IDE's wouldn't be able to infer the type of the result of these operations).
    #
    def __add__(self, other) -> "Array":
        return add(self, other)

    def __sub__(self, other) -> "Array":
        return subtract(self, other)

    def __mul__(self, other) -> "Array":
        return multiply(self, other)

    def __truediv__(self, other) -> "Array":
        return divide(self, other)

    # Right-hand-side (`other * self`) and in-place (`self *= other`) versions
    __radd__ = __add__
    __iadd__ = __add__
    __rsub__ = __sub__
    __isub__ = __sub__
    __rmul__ = __mul__
    __imul__ = __mul__
    __itruediv__ = __truediv__
    __rtruediv__ = __truediv__


class Quantity(Array):
    pass