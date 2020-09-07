from .array import Array, create_new_Array_or_Quantity
from ..type_aliases import Scalar
from ..unit import Unit


class Quantity(Array):
    """
    A scalar number with a physical unit.

    See `Array`.
    """

    def __new__(cls, value, *args, **kwargs):
        return create_new_Array_or_Quantity(value)

    def __init__(
        self,
        value: Scalar,
        display_unit: Unit,
        value_is_given_in_display_units: bool = True,
    ):
        """
        :param value:  A Python or NumPy scalar number.
        :param display_unit:  Units in which to display the value.
        :param value_is_given_in_display_units:  If True (default), the given `value` is
                    taken to be expressed in `display_unit`s, and is converted to and
                    stored internally in `display_unit.base_unit`s. If False, `value`
                    is taken to be already expressed in `display_unit.base_unit`s,
                    and no conversion is done.
        """
        super().__init__(value, display_unit, value_is_given_in_display_units)

    @property
    def value(self):
        return self.data.item()

    @property
    def value_in_display_units(self) -> Scalar:
        return self.data_in_display_units.item()

    vd: Scalar = value_in_display_units  # Shorthand

    @property
    def value_unit(self):
        return self.data_unit

    _DIY_help_text = (
        "You can get the bare numeric value via `your_quantity.value` "
        "and work with it manually."
    )
