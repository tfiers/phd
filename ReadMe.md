# Voltage-to-wiring, the simulation

In vivo connectomics -- mapping the wires between neurons based on voltage imaging recordings.\
Proof of concept simulation.

For documentation & rendered notebooks: &nbsp; [![](https://img.shields.io/badge/%F0%9F%9A%80_open_website-green)](https://tfiers.github.io/voltage-to-wiring-sim)


<br>

## Installation

The code is written in Python 3.8.

<details><summary>[How to install Python and Jupyter, using 'conda']</summary>
To setup your local machine for running this project, I recommend the <a href="https://docs.conda.io/">conda</a> package manager,
specifically its small <a href="https://docs.conda.io/en/latest/miniconda.html">miniconda</a> installer.<br>
Installing conda will also install Python, and the `pip` Python package installer used below.<br>
If Python's version is not already at least 3.8 (checked with <code>python --version</code>),
upgrade using <code>conda update python</code>.<br>
Install the Jupyter notebook server using <code>conda install notebook</code>.  
After cloning this repository, follow the package installation instructions below.
Finally, you can run <code>python -m notebook</code>. This will open the Jupyter app locally, in your browser,
in which you can play with the notebooks, which run the simulation/analysis code and display the results.
</details>

When you have installed Python, download/clone this repository (using the green "Code" button on GitHub).

[`setup.py`](setup.py) contains a list of external packages on which this code depends,
including short descriptions of what each is used for.

Install the code and these dependencies by running, in the project root directory:
```bash
pip install -e .
```
(The `-e` stands for `editable`, meaning you can change the source code 
— found in [`codebase/voltage_to_wiring_sim/`](codebase/voltage_to_wiring_sim/) — 
and then use this updated code in your scripts and notebooks, without having to reinstall
the package).


<br>

## Usage

You should now be able to import the code as a package into scripts and notebooks:
```py
import voltage_to_wiring_sim as v  # example shorthand
```

Get going quickly in a Jupyter notebook (or an IPython REPL session), by running:
```py
from voltage_to_wiring_sim.support.notebook_init import *
```
This imports useful packages (`numpy as np`, `voltage_to_wiring_sim as v`, etc), and 
configures IPython (like enabling `%autoreload`, 'retina' figures, nice number formatting, etc).


More explanation on the code can be found in the [Python files](codebase/voltage_to_wiring_sim/) 
themselves in, as comments and docstrings.


<br>

## Tests

Some modules contain small `test()` functions to showcase how the module is used.
These are to be run manually (and not with an automated test runner like pytest).

Instructions on how to run/debug these in PyCharm:
1. Create a scratch file.
2. In it, `import voltage_to_wiring_sim as v` and call `v.synapses.test()`, e.g.
3. Run/debug this scratch file.

To run in a notebook, just do the second step. 

The reason for this verbosity is that modules shouldn't be run as scripts (it's also not
easy -- it errors e.g. on relative imports) -- but I still wanted my test code to be
close to the code that it's testing/showcasing.


<br>

## Licenses

The favicon for the website is © 2020 The Jupyter Book Community, 
licensed under [their BSD-3-clause license](https://github.com/executablebooks/jupyter-book/blob/main/LICENSE).
