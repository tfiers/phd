
from plot import *
from brian2.numpy_ import *

print("importing pandas", end=" … ")
import pandas as pd
print("✔")

pS = psiemens
minute = 60 * second
minutes = minute
seconds = second

Vs = 40 * mV  # Copied (🤷) from Nto1AdEx.Vₛ

def ceil_spikes_jl(sim):
    V = sim.V * volt
    return ceil_spikes(V, timesig(V), sim.spiketimes * second)

def ceil_spikes(V, t, spiketimes, V_ceil=Vs):
    "For nice plots, set the voltage trace to some constant at spike times"
    i = searchsorted(t, spiketimes)
    V[i] = V_ceil
    return V

from collections import Counter

def units_to_header(df):
    df = df.copy()
    for col in df:
        x = df[col].values[-1]
        if type(x) == Quantity:
            c = Counter(el.get_best_unit() for el in df[col])
            unit = c.most_common()[0][0]
            df[col] = [val / unit for val in df[col]]
            df[col].unit = unit
            df.rename(columns={col: f"{col}_{unit}"}, inplace=True)
        else:
            df[col].unit = None
    return df
