from dataclasses import dataclass

import numpy as np

from .units import Quantity, second


@dataclass
class TimeGrid:
    duration: Quantity
    timestep: Quantity
    start: Quantity = 0 * second

    @property
    def N(self):
        """ number of time bins """
        return round(self.duration / self.timestep)

    @property
    def bounds(self):
        return self.start + np.array([0, self.duration])

    @property
    def time(self):
        """ for plotting """
        return np.linspace(*self.bounds, self.N, endpoint=False)

    @property
    def i_slice(self):
        """ to index into a Signal with the same timestep """
        index_bounds = np.round(self.bounds / self.timestep).astype(int)
        return slice(*index_bounds)
