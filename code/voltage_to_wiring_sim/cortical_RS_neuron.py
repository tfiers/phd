# Izhikevich neuron model parameters for a cortical regular spiking (RS) neuron.

from unyt import pF, pA, mV, ms

# fmt: off
# (This is a directive for my auto-formatter ("Black") to not destroy the manual
# alignment below).

izh_params = {
    "C":      100  * pF,
    "k":      0.7  * pA/(mV**2),
    "v_r":    -60  * mV,
    "v_t":    -40  * mV,
    "v_peak":  35  * mV,
    "a":      0.03 * 1/ms,
    "b":      -2   * pA/mV,
    "c":      -50  * mV,
    "d":      100  * pA,
}
