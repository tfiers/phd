# Import various modules and objects into the package namespace, so we have easy access
# via tab-completion in an interactive session.
from . import neuron_sim, params, plot_style, spike_train, synapses, units
from .neuron_sim import simulate_izh_neuron
from .plot_style import figsize
from .spike_train import generate_Poisson_spike_train
from .synapses import calc_synaptic_conductance
from .time_grid import TimeGrid