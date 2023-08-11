# Conductance-based AdEx neuron.
# Parameters for a cortical regular spiking (RS) neuron, from Naud 2008.

from util import *
from brian2 import *

set_seed = seed

C   = 104  * pF
gL  = 4.3  * nS
EL  = -65  * mV
VT  = -52  * mV
DT  = 0.8  * mV
Vs  =  40  * mV
Vr  = -53  * mV
a   = -0.8 * nS
b   =  65  * pA
tau_w = 88 * ms

Ee  =   0  * mV
Ei  = -80  * mV
tau_g = 7  * ms


eqs = """
dV/dt = ( -gL*(V - EL) + gL * DT * exp((V-VT)/DT) -I -w) / C : volt
dw/dt = (a*(V - EL) - w) / tau_w : amp

I = ge * (V - Ee) + gi * (V - Ei) : amp

dge/dt = -ge / tau_g : siemens
dgi/dt = -gi / tau_g : siemens
"""

def COBA_AdEx_neuron(N = 1):
    n = NeuronGroup(N, eqs, threshold="V > Vs", reset="V = Vr; w += b", method='euler')
    n.V = EL
    # Rest of vars are auto set to 0
    return n


def ceil_spikes_brian(M: StateMonitor, S: SpikeMonitor, var='V', n=0, V_ceil=Vs):
    "For nice plots, set the voltage trace to some constant at spike times"
    V = getattr(M, var)[n]
    spikes = S.t[S.i == n]
    return ceil_spikes(V, M.t, spikes, V_ceil)
