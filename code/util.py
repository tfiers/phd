from functools import wraps

from unyt import unyt_array


def strip_input_units(original_function):
    """
    Converts arguments to SI units and removes their unit.
    
    Function decorator that
    1) scales inputs of type `unyt_quantity` or `unyt_array` to their base SI value
    ("mks" values, meter-kilogram-second), and
    2) converts them to simple NumPy arrays or plain Python scalars, thus stripping
    their units.
    This results in less overhead when the values are used in calculation, and thus a
    faster function.
    """

    def process_arg(value):
        if isinstance(value, unyt_array):
            # `unyt_quantity` is a subclass of `unyt_array` (so we will catch both).
            return strip(value)
        else:
            return value

    def strip(quantity: unyt_array):
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

    @wraps(original_function)
    def modified_function(*args, **kwargs):
        args = (process_arg(val) for val in args)
        kwargs = {key: process_arg(val) for key, val in kwargs.items()}
        return original_function(*args, **kwargs)

    return modified_function
