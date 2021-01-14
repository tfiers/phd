import functools
import reprlib
import sys
from dataclasses import asdict, fields
from functools import partial
from textwrap import fill
from typing import Callable, Optional, Sequence, Tuple, Union

import matplotlib.pyplot as plt
import numba
import numpy as np
from matplotlib.axes import Axes
from matplotlib.figure import Figure
from tqdm import tqdm

from .array_wrapper import strip_NDArrayWrapper_inputs


timed_loop = partial(tqdm, file=sys.stdout)
# By default, tqdm writes its progress bar to stderr ("stdout should only be used for
# program output"). But stderr gives red bg in jupyter nbs which is not nice.


def pprint(dataclass, values=True):
    """
    Pretty-prints a dataclass as a table of its fields and their values, and with the
    class name as header.
    """

    ddict = asdict(dataclass)
    len_longest_name = max(len(name) for name in ddict.keys())

    dataclass_name = dataclass.__class__.__name__
    header_lines = [
        dataclass_name,
        "-" * len(dataclass_name),
    ]

    def pprint(value):
        if isinstance(value, float):
            return format(value, ".4G")
        else:
            return fill(
                reprlib.repr(value),  # reprlib abbreviates long lists
                subsequent_indent=(len_longest_name + 4) * " ",
            )

    if values:
        content_lines = [
            f"{name:>{len_longest_name}} = {pprint(value)}"
            for name, value in ddict.items()
        ]
    else:
        content_lines = [
            f"{field.name:<{len_longest_name}}: {field.type}"
            for field in fields(dataclass)
        ]

    print("\n".join(header_lines + content_lines))


def fix_rng_seed(seed=0):
    """
    Set seed of random number generator, to generate same random sequence in every
    script run, and thus get same results.
    """
    np.random.seed(seed)


# Add return types to plt.subplots (for autocompletion in IDE).

OneOrMoreAxes = Union[Axes, Sequence[Axes]]


def subplots(**kwargs) -> Tuple[Figure, OneOrMoreAxes]:
    return plt.subplots(**kwargs)


functools.update_wrapper(subplots, plt.subplots)


def create_if_None(ax: Optional[Axes], **subplots_kwargs):
    if ax is None:
        _, ax = subplots(**subplots_kwargs)
    return ax



# A clearer name for the numba `(n)jit` call.
def compile_to_machine_code(function: Callable = None, *, parallel=False) -> Callable:
    # If `function` is given, the decorator was applied as `@compile_to_machine_code`
    # (or as `g = compile_to_machine_code(f)`). If not, the decorator was applied like
    # `@compile_to_machine_code(parallel=...)`
    def decorate(function):
        jit_compiled_function = numba.jit(
            function,
            nopython=True,  # In 'nopython' mode, the function is compiled to run
            #                 entirely without the Python interpreter (if possible;
            #                 otherwise an error is thrown at compile time).
            cache=False,  # File-based cache (on top of the default per-session memory
            #               cache).
            parallel=parallel,
        )
        final_function = strip_NDArrayWrapper_inputs(jit_compiled_function)
        #   Numba cannot work with our custom array wrapper classes -- only with pure
        #   ndarrays. Hence we unwrap such inputs, if present.
        functools.update_wrapper(final_function, function)
        #   Copy over docstring, module, annotations, etc. Original function is found in
        #   `final_function.__wrapped__`.
        final_function.jit_compiled_function = jit_compiled_function
        #   Give acces
        return final_function

    if function is None:
        return decorate
    else:
        return decorate(function)
