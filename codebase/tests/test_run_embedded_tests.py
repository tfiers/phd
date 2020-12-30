"""
Weird file name and function name ("test..tests") is because pytest's default automatic
test discovery expects files and functions to start with "test_"
"""

import voltage_to_wiring_sim as v


def test__run_embedded_tests():
    v.spike_trains.test()
    v.synapses.test()
    v.neuron_sim.test()
    v.connection_test.test()
