import numpy as np
from unyt import unyt_array, ms, min, s

T = 1 * s  # simulation duration
dt = 0.1 * ms  # timestep
N = round(T / dt)  # number of simulation steps

# time array, for plotting
t: unyt_array = np.linspace(0, T, N, endpoint=False)
t.name = "Time"
