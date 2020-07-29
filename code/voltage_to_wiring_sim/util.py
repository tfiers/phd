from contextlib import contextmanager
from time import time

import numpy


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
