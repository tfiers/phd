from preload import preload

preload(["numpy", "matplotlib.pyplot", "numba"])

print("Importing from submodules (compiling numba functions)", end=" … ")

from .neuron_sim import simulate_izh_neuron
from .spike_train import (
    generate_Poisson_spike_train,
    spike_train_to_indices,
    spike_train_from_indices,
)
from .synapses import calc_synaptic_conductance
from .imaging import add_VI_noise
from .STA import make_windows, calculate_STA, plot_STA
from .support.plot_style import figsize
from .support.time_grid import TimeGrid
from .support.scalebar import add_scalebar
from .support.util import fix_rng_seed, pprint
from .support.reproducibility import print_reproducibility_info

# noinspection PyUnresolvedReferences
from . import imaging, neuron_sim, params, spike_train, STA, synapses, support

print("✔\n")
