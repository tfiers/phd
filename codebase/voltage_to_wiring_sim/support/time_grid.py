from dataclasses import dataclass

from numpy import linspace

from .units import Array, Quantity


@dataclass
class TimeGrid:
    T: Quantity  # simulation duration
    dt: Quantity  # timestep
    N: int = None  # number of simulation steps
    t: Array = None  # time array, for plotting

    def __post_init__(self):
        self.N = round(self.T / self.dt)
        self.t = linspace(0, self.T, self.N, endpoint=False)
        self.t.name = "Time"
