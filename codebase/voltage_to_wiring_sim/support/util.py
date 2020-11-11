from dataclasses import asdict, dataclass
from typing import Sequence, Tuple, Union

import matplotlib.pyplot as plt
import numpy
from matplotlib.axes import Axes
from matplotlib.figure import Figure


@dataclass
class QuantityCollection:
    """ A collection of dimensioned values, with pretty printing ability. """

    def __str__(self):
        """ Invoked when calling `print()` on the dataclass. """
        subclass_name = self.__class__.__name__
        lines = [
            subclass_name,
            "-" * len(subclass_name),
        ]
        for name, value in asdict(self):
            lines.append(f"{name} = {str(value)}")
        return "\n".join(lines)


def fix_rng_seed(seed=0):
    """
    Set seed of random number generator, to generate same random sequence in every
    script run, and thus get same results.
    """
    numpy.random.seed(seed)


# Add return types to plt.subplots (for autocompletion in IDE).
def subplots(**kwargs) -> Tuple[Figure, Union[Axes, Sequence[Axes]]]:
    return plt.subplots(**kwargs)


subplots.__doc__ = plt.subplots.__doc__
