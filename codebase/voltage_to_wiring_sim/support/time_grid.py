from dataclasses import dataclass

from numpy import linspace

from .units import Array, Quantity


@dataclass
class TimeGrid:
    duration: Quantity  # simulation duration
    dt: Quantity  # timestep
    N: int = None  # number of simulation steps
    t: Array = None  # time array, for plotting

    def __post_init__(self):
        self.N = round(self.duration / self.dt)
        self.t = linspace(0, self.duration, self.N, endpoint=False)
        # self.t.name = "Time"
