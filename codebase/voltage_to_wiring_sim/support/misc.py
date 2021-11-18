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
