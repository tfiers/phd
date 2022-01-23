import functools
from typing import Callable

import joblib
import numba

from .array_wrapper import strip_NDArrayWrapper_inputs


joblib_cache = joblib.Memory(location=".", verbose=1)


def cache_to_disk(function=None, *, directory: str = None, **joblib_kwargs):
    def decorate(func):
        if directory:
            # Hack to make joblib store the cache for functions defined in a notebook in
            # a directory with a clear name (instead of the default
            # kernel-path-and-hash).
            func.__module__ = f"notebooks.{directory}"
        return joblib_cache.cache(func, **joblib_kwargs)

    if function is not None:
        return decorate(function)
    else:
        return decorate


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


runner = joblib.Parallel(n_jobs=-1)


def run_in_parallel(f, args):
    """ Output printing is not done in notebook, but in jupyter terminal """
    return runner(joblib.delayed(f)(arg) for arg in args)
