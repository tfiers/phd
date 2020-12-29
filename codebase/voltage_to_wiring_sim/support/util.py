import functools
import reprlib
from dataclasses import asdict
from typing import Callable, Sequence, Tuple, Union

import matplotlib.pyplot as plt
import numba
import numpy
from matplotlib.axes import Axes
from matplotlib.figure import Figure

from .array_wrapper import strip_NDArrayWrapper_inputs


def pprint(dataclass):
    """
    Pretty-prints a dataclass as a table of its fields and their values, and with the
    class name as header.
    """
    dataclass_name = dataclass.__class__.__name__
    header_lines = [
        dataclass_name,
        "-" * len(dataclass_name),
    ]

    def pprint(value):
        if isinstance(value, float):
            return format(value, ".4G")
        else:
            return reprlib.repr(value)  # reprlib abbreviates long lists

    content_lines = [
        f"{name} = {pprint(value)}" for name, value in asdict(dataclass).items()
    ]
    
    print("\n".join(header_lines + content_lines))


def fix_rng_seed(seed=0):
    """
    Set seed of random number generator, to generate same random sequence in every
    script run, and thus get same results.
    """
    numpy.random.seed(seed)


# Add return types to plt.subplots (for autocompletion in IDE).

OneOrMoreAxes = Union[Axes, Sequence[Axes]]


def subplots(**kwargs) -> Tuple[Figure, OneOrMoreAxes]:
    return plt.subplots(**kwargs)


functools.update_wrapper(subplots, plt.subplots)


# A clearer name for the numba `(n)jit` call.
def compile_to_machine_code(function: Callable) -> Callable:
    # In 'nopython' mode, the function is compiled to run entirely without the Python
    # interpreter (if possible; otherwise an error is thrown at compile time).
    jit_compiled_function = numba.jit(function, nopython=True, cache=True)
    # Numba cannot work with our custom array wrapper classes -- only with pure
    # ndarrays. Hence we unwrap such inputs, if present.
    final_function = strip_NDArrayWrapper_inputs(jit_compiled_function)
    functools.update_wrapper(final_function, function)
    return final_function
