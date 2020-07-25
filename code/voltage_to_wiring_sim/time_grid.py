from dataclasses import dataclass, field

from numpy import linspace
from unyt import ms, s, unyt_array, unyt_quantity


@dataclass
class TimeGrid:
    T: unyt_quantity  # simulation duration
    dt: unyt_quantity  # timestep
    N: int = field(init=False)  # number of simulation steps
    t: unyt_array = field(init=False)  # time array, for plotting

    def __post_init__(self):
        self.N = int(round(self.T / self.dt))
        self.t = linspace(0, self.T, self.N, endpoint=False)
        self.t.convert_to_units(ms)
        self.t.name = "Time"


short_time_grid = TimeGrid(T=0.5 * s, dt=0.5 * ms)
