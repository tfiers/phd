from dataclasses import dataclass

from ..support.units import Quantity, mV, ms, nS, pA, pF


# fmt: off

@dataclass
class IzhikevichParams:
    C:      Quantity   # Capacitance
    k:      Quantity   # A voltage-dependent conductance derived from neuron's I-V curve.
    v_r:    Quantity   # Resting potential
    v_t:    Quantity   # "Instantenous" threshold. (Approximate firing threshold)
    v_peak: Quantity   # Spike cut-off voltage
    a:      Quantity   # 1 / time constant of dominant slow current (`u`; K⁺)
    b:      Quantity   # A conductance derived from neuron's I-V curve
    c:      Quantity   # Reset potential
    d:      Quantity   # Free parameter ("net current activated during spike")
    v_syn:  Quantity   # Synaptic reversal potential


# Cortical regular spiking (RS) neuron.
cortical_RS = IzhikevichParams(
    C = 100 * pF,
    k = 0.7 * (nS/mV),
    b = -2 * nS,
    v_r    = -60 * mV,
    v_t    = -40 * mV,
    v_peak =  35 * mV,
    v_syn  =   0 * mV,
    c      = -50 * mV,
    a = 0.03 / ms,
    d = 100 * pA,
)
