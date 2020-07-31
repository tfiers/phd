from dataclasses import dataclass

from numpy import linspace

from .units import Array, Quantity, QuantityCollection, unyt_array


@dataclass
class TimeGrid(QuantityCollection):
    T: Quantity  # simulation duration
    dt: Quantity  # timestep
    N: int = None  # number of simulation steps
    t: Array = None  # time array, for plotting

    def __post_init__(self):
        self.N = int(round(self.T / self.dt))
        t: unyt_array = linspace(0, self.T, self.N, endpoint=False)
        self.t = Array(t.in_units(self.T.display_units), name="Time")
