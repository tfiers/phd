from dataclasses import dataclass

import numpy as np

from .units import Quantity, second


@dataclass
class TimeGrid:
    duration: Quantity
    timestep: Quantity
    start: Quantity = 0 * second

    def __post_init__(self):
        self.N = round(self.duration / self.timestep)  # number of time bins
        self.bounds = self.start + np.array([0, self.duration])
        self.time = np.linspace(*self.bounds, self.N, endpoint=False)  # for plotting
        index_bounds = np.round(self.bounds / self.timestep).astype(int)
        self.i_slice = slice(*index_bounds)  # to index into a Signal with the same
        #                                      timestep.
