from preload import preload

preload(["numpy", "matplotlib.pyplot", "numba"])

print("Importing from submodules (compiling numba functions)", end=" … ")

from .neuron_sim import simulate_izh_neuron
from .spike_trains import generate_Poisson_spikes
from .synapses import calc_synaptic_conductance
from .imaging import add_VI_noise
from .STA import calculate_STA, plot_STA
from .connection_test import test_connection
from .support.plot_style import figsize
from .support.time_grid import TimeGrid
from .support.scalebar import add_scalebar
from .support.util import fix_rng_seed, pprint
from .support.reproducibility import print_reproducibility_info

from . import params  # to satisfy PyCharm in test_connection.py > test()

print("✔\n")
