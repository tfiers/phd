# Import various modules into the package namespace, so we have easy access via
# tab-completion in an interactive session.
from . import params, neuron_sim, synapses, plot_style, spike_train, units
from .time_grid import TimeGrid
from .neuron_sim import simulate_izh_neuron
from .spike_train import generate_Poisson_spike_train
from .synapses import calc_synaptic_conductance
from .plot_style import figsize
