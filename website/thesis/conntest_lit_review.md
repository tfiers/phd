# Network inference – literature review


Quite some papers resolve around the _Neural Connectomics Challenge_, which was organized in 2014. 


## Timme group's _Event space linearization_.

{cite}`casadiegoInferringNetworkConnectivity2018`,



```{figure} images/event_space_linearization.png
Three panels from {cite:ts}`casadiegoInferringNetworkConnectivity2018` showing the idea behind their _event space linearization_ method for detecting connections. The notation used is as follows: 
$i$ is the neuron for which we want to determine the incoming connections.
The other neurons are indexed by $j$.
$ΔT_i$ is an inter-spike interval (ISI) of the studied neuron.
As shown in panel **a**, the spikes of the other neurons during this ISI are gathered. The _cross-spike intervals_ (CSIs) between these spikes and the start of the ISI are denoted by $w_{jk}^i$, with $k$ standing for the $k$-th spike of neuron $j$ within the ISI.
As shown in panel **b**, the method asserts that the ISI is a function $h^i$ of all these CSIs (gathered in the matrix $\bold{w}^i$), filtered by the connectivity (via the diagonal matrix $Λ^i$, with $Λ^i_{jj} = 1$ if neuron $j$ sends a connection to neuron $i$, and $0$ otherwise).
In **c**, the partial derivative of this function with respect to the first CSI of each neuron ($W^i_{j1} ≡ w^i_{j1}$) is plotted.
```
%i.e. how long it took for neuron $j$ to spike for the first time after the start of the ISI).

```{bibliography}
:style: unsrt
```
