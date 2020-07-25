from dataclasses import dataclass

from .units import QuantityCollection, mV, ms, nS, pA, pF, unyt_quantity


# fmt: off

@dataclass
class IzhikevichParams(QuantityCollection):
    C:      unyt_quantity   # Capacitance
    k:      unyt_quantity   # A voltage-dependent conductance derived from neuron's I-V curve.
    v_r:    unyt_quantity   # Resting potential
    v_t:    unyt_quantity   # "Instantenous" threshold. (Approximate firing threshold)
    v_peak: unyt_quantity   # Spike cut-off voltage
    a:      unyt_quantity   # 1 / time constant of dominant slow current (`u`; K⁺)
    b:      unyt_quantity   # A conductance derived from neuron's I-V curve
    c:      unyt_quantity   # Reset potential
    d:      unyt_quantity   # Free parameter ("net current activated during spike").
    v_syn:  unyt_quantity   # Synaptic reversal potential


# Cortical regular spiking (RS) neuron.
cortical_RS = IzhikevichParams(
    C = 100*pF,
    k = 0.7*nS/mV,
    b = -2*nS,
    v_r    = -60*mV,
    v_t    = -40*mV,
    v_peak =  35*mV,
    v_syn  =   0*mV,
    c      = -50*mV,
    a = 0.03/ms,
    d = 100*pA,
)
