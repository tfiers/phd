import random
from dataclasses import fields
from typing import Any, Type

import numpy as np


def fix_rng_seed(seed=0):
    """
    Set seed of random number generator, to generate same random sequence in every
    script run, and thus get same results.
    """
    random.seed(seed)
    np.random.seed(seed)


SomeDataclass = Any

# hacky way to initialise a dataclass based on locals() dict.
def fill_dataclass(Dataklasss: Type[SomeDataclass], lokals: dict) -> SomeDataclass:
    kwargs = {}
    for field in fields(Dataklasss):
        kwargs[field.name] = lokals[field.name]
    return Dataklasss(**kwargs)


def round_stochastically(x: float) -> int:
    """Rounds a value 4.2 up with probability 0.2 and down with prob. 0.8"""
    return int(x + random.random())


def indices_where(bool_array):
    return np.nonzero(bool_array)[0]


def to_indices(times, dt):
    """Returns a numpy int or array of ints."""
    return np.round(np.array(times) / dt).astype(int)
