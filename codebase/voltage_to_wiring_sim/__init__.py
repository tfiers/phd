from preload import preload

preload(["numpy", "matplotlib.pyplot", "numba", "unitlib"])

print("Importing from submodules (compiling numba functions)", end=" … ")

from .neuron_sim import simulate_izh_neuron
from .spike_train import generate_Poisson_spike_train
from .synapses import calc_synaptic_conductance
from .support.plot_style import figsize
from .support.time_grid import TimeGrid
from .support.scalebar import add_scalebar
from .support.util import fix_rng_seed, pprint
from .support.reproducibility import print_reproducibility_info

print('✔\n')
