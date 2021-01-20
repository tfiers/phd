import functools
import reprlib
from contextlib import contextmanager
from dataclasses import asdict, fields
from textwrap import fill
from time import time
from typing import Callable, Optional, Sequence, Tuple, Union

import matplotlib.pyplot as plt
import numba
import numpy as np
from matplotlib.axes import Axes
from matplotlib.figure import Figure

from .array_wrapper import strip_NDArrayWrapper_inputs


@contextmanager
def time_op(description: str, end="\n"):
    bsprint(f"{description}: ", end="")
    t0 = time()
    yield
    dt = time() - t0
    duration_str = f"[{dt:.2g} s]"
    bsprint(f"{duration_str:<8}", end=end)


def with_progress_meter(sequence, end=" "):
    # We don't use the standard solution, `tqdm`, as it adds a trailing newline and can
    # thus not be integrated in a gradual, one-line printing context.
    total = len(sequence)
    for i, item in enumerate(sequence):
        meter_str = f"{i}/{total}"
        bsprint(meter_str, end="")
        yield item
        bsprinter.backspace(len(meter_str))
    bsprint(f"{total}/{total}", end=end)


class BackspaceablePrinter:
    # Printing backspace characters (`\b`) does not work in Jupyter Notebooks
    # [https://github.com/jupyter/notebook/issues/2892].
    # Hence we emulate it by erasing the entire line (which does work), and reprinting
    # what was already there. The goal? Progress meters (see `with_progress_meter`).

    def __init__(self):
        self.last_line = ""

    def print(self, msg: str, end="\n"):
        """ Use if you later want to be able to backspace in the same line."""
        full_msg = msg + end
        if "\n" in full_msg:
            self.last_line = ""
        self.last_line += full_msg.split("\n")[-1]
        print(full_msg, end="")

    def backspace(self, num=1):
        self.last_line = self.last_line[:-num]
        print(f"\r{self.last_line}", end="")


bsprinter = BackspaceablePrinter()
bsprint = bsprinter.print


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
