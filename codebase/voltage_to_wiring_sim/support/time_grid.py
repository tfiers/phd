from dataclasses import dataclass

import numpy as np

from .units import Array, Quantity


@dataclass
class TimeGrid:
    duration: Quantity  # simulation duration
    timestep: Quantity  # timestep
    N: int = None  # number of simulation steps
    t: Array = None  # time array, for plotting

    def __post_init__(self):
        self.N = round(self.duration / self.timestep)
        self.t = np.linspace(0, self.duration, self.N, endpoint=False)
        # self.t.name = "Time"
