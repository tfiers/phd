"""
Weird file name and function name ("test..tests") is because pytest's default automatic
test discovery expects files and functions to start with "test_"
"""

import voltage_to_wiring_sim as v


def test__run_embedded_tests():
    v.sim.poisson_spikes.test()
    v.sim.synapses.test()
    v.sim.izhikevich_neuron.test()
    v.conntest.permutation_test.test()
