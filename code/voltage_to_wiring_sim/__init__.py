# Import various modules and objects into the package namespace, so we have easy access
# via tab-completion in an interactive session.
from . import (
    neuron_params,
    neuron_sim,
    plot_style,
    presynaptic_spike_train,
    units,
    time_grid,
)
from .time_grid import short_time_grid
