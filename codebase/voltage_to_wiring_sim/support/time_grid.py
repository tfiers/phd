from dataclasses import dataclass

import numpy as np

from .units import Array, Quantity


@dataclass
class TimeGrid:
    duration: Quantity  # simulation duration
    timestep: Quantity  # timestep
    N: int = ...  # number of simulation steps

    def __post_init__(self):
        self.N = round(self.duration / self.timestep)

    @property
    def time(self) -> Array:
        """ time array, for plotting """
        return np.linspace(0, self.duration, self.N, endpoint=False)
