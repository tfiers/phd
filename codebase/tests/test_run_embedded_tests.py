import voltage_to_wiring_sim as v


def test__run_embedded_tests():
    v.spike_trains.test()
    v.synapses.test()
    v.neuron_sim.test()
    v.connection_test.test()
