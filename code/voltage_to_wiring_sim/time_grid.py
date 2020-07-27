from dataclasses import dataclass, field

from numpy import linspace
from unyt import ms, s, unyt_array, unyt_quantity

from .units import QuantityCollection


@dataclass
class TimeGrid(QuantityCollection):
    T: unyt_quantity  # simulation duration
    dt: unyt_quantity  # timestep
    N: int = None  # number of simulation steps
    t: unyt_array = None  # time array, for plotting

    def __post_init__(self):
        self.N = int(round(self.T / self.dt))
        self.t = linspace(0, self.T, self.N, endpoint=False)
        self.t.name = "Time"


short_time_grid = TimeGrid(T=(1 * s).in_units(ms), dt=0.1 * ms)
