from contextlib import contextmanager
from time import time
from typing import Sequence, Tuple, Union

import matplotlib.pyplot as plt
import numpy
from matplotlib.axes import Axes
from matplotlib.figure import Figure


@contextmanager
def report_duration(action_description: str):
    print(action_description, end=" … ")
    t0 = time()
    yield
    duration = time() - t0
    print(f"✔ ({duration:.2g} s)")


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
