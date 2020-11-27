from dataclasses import asdict
from typing import Sequence, Tuple, Union

import matplotlib.pyplot as plt
import numpy
from matplotlib.axes import Axes
from matplotlib.figure import Figure


def pprint(dataclass):
    """
    Pretty-prints a dataclass as a table of its fields and their values, and with the
    class name as header.
    """
    dataclass_name = dataclass.__class__.__name__
    lines = [
        dataclass_name,
        "-" * len(dataclass_name),
    ]
    for name, value in asdict(dataclass).items():
        lines.append(f"{name} = {str(value)}")
    print("\n".join(lines))


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
