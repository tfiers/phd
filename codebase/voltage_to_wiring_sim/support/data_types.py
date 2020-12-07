from typing import Any, NewType

from nptyping import NDArray


num_spikes = Any
num_samples = Any


SpikeTimes = NewType("SpikeTimes", NDArray[(num_spikes,), float])
#   A collection of spike times; i.e. not a full "0/1" signal. Assumed to be sorted
#   (increasing in time).


SpikeIndices = NewType("SpikeIndices", NDArray[(num_spikes,), int])
#   Like `SpikeTimes`, but expressed in number of samples since the start of the signal.


InterSpikeIntervals = NewType("InterSpikeIntervals", NDArray[(num_spikes,), float])
