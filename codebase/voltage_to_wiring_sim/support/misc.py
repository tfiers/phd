import functools
import random
from typing import Callable

import numba
import numpy as np
import joblib

from .array_wrapper import strip_NDArrayWrapper_inputs


joblib_cache = joblib.Memory(location='.', verbose=1)
cache_to_disk = joblib_cache.cache


def fix_rng_seed(seed=0):
    """
    Set seed of random number generator, to generate same random sequence in every
    script run, and thus get same results.
    """
    random.seed(seed)
    np.random.seed(seed)


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
