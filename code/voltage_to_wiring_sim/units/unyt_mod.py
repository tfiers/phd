"""
Extensions to the unyt package.
"""

import unyt
from unyt import unyt_array, unyt_quantity


class Unit(unyt.Unit):
    """
    Extend Unit so that `a = 8 * mV` will be our custom Quantity, and not a
    unyt_quantity.
    """

    def __mul__(self, other):
        obj = super().__mul__(other)
        return self._convert(obj)

    def __truediv__(self, other):
        obj = super().__truediv__(other)
        return self._convert(obj)

    def __rtruediv__(self, other):
        obj = super().__rtruediv__(other)
        return self._convert(obj)

    @staticmethod
    def _convert(obj):
        # unyt_quantity check must come before unyt_array, as the former is a subclass
        # of the latter.
        if isinstance(obj, unyt_quantity):
            return Quantity(obj)
        elif isinstance(obj, unyt_array):
            return Array(obj)
        else:
            # We're making a compound unit (`nS/mV` eg).
            return Unit(obj)


class Array(unyt_array):
    """
    Subclass of `numpy.ndarray` and `unyt_array` that stores its contents in base SI
    units.
    Conversion from/to physiological (i.e. most natural) units is done only at user
    interaction time. That is, when:
     - defining
     - printing
     - plotting
    ..the array or quantity.
    
    Get the data (in base units), using `a.ndarray_view() == a.ndview == a.d`.
    """

    # To understand `__new__` and `__array_finalize__`, see NumPy's "Subclassing
    # ndarray" article: [https://numpy.org/doc/stable/user/basics.subclassing.html]

    display_units: Unit

    def __new__(cls, *args, **kwargs):
        obj: Array = super().__new__(cls, *args, **kwargs)
        # Store units used to define the quantity.
        obj.display_units = obj.units
        # Convert to base SI units.
        # unyt's `convert_to_base()` always returns a float datatype -- but for eg
        # counts we want to keep the integer datatype. Thus we don't call
        # `convert_to_base` for dimensionless datatypes. (Dimensionless quantities
        # needn't be converted to a base unit anyway).
        if not obj.units.is_dimensionless:
            # If the input array is given as integers (which have a default dtype of
            # int32), `convert_to_base` would convert them to float32. We prefer more
            # precise float64; so cast explicitly.
            obj = obj.astype("float64")
            # mks = meter-kilogram-system = base (i.e. prefixless) SI units.
            obj.convert_to_base("mks")
        return obj

    def __array_finalize__(self, obj):
        # Make sure array slices are also Arrays/Quantities.
        super().__array_finalize__(obj)
        self.display_units = getattr(obj, "display_units", None)

    @property
    def in_display_units(self):
        if self.units.is_dimensionless:
            # Keep integer datatype. (See note on dimensionless quantities in __new__).
            return unyt_array(self)
        else:
            # Note that we can't return `self.to(self.display_units)` here, as that
            # would convert to base units again (in __new__).
            return unyt_array(self).to(self.display_units)

    def __repr__(self):
        clsname = self.__class__.__name__
        if self.units.is_dimensionless:
            return f"{clsname}({str(self)}, {self.dtype})"
        else:
            return f"{clsname}({str(self)}, stored in {self.units}, {self.dtype})"

    def __str__(self):
        if self.units.is_dimensionless:
            return f"{self.value} (dimensionless)"
        else:
            return str(self.in_display_units)


class Quantity(Array, unyt_quantity):
    pass


#
# Matplotlib support for our new Array and Quantity classes.
# Goal is to get our plot axes automatically labelled with units and signal names.

import matplotlib.units
from unyt.mpl_interface import unyt_arrayConverter


class MatplotlibArrayConvertor(unyt_arrayConverter):
    def __new__(cls):
        # unyt's unyt_arrayConverter() is a singleton.
        # Override its __new__ method to not get that singleton instance for our
        # subclass.
        return super(matplotlib.units.ConversionInterface, cls).__new__(cls)

    @staticmethod
    def default_units(x: Array, axis):
        unyt_arrayConverter().default_units(x, axis)
        return x.display_units

    @staticmethod
    def convert(value: Array, unit, axis):
        return unyt_arrayConverter().convert(value.in_display_units, unit, axis=axis)


matplotlib.units.registry[Array] = MatplotlibArrayConvertor()
matplotlib.units.registry[Quantity] = MatplotlibArrayConvertor()
