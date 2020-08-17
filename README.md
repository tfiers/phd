# Voltage-to-wiring, the simulation

In vivo connectomics -- mapping the wires between neurons based on voltage imaging recordings.\
Proof of concept simulation.

For documentation & rendered notebooks: &nbsp; [![](https://img.shields.io/badge/%F0%9F%9A%80_open_website-green)](https://tfiers.github.io/voltage-to-wiring-sim)


<br>

## Installation

The code is written in Python 3.8.

<details><summary>[Installing Python and Jupyter, using conda])</summary>
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

[`setup.py`](setup.py) contains a list of external packages on which this code depends,
including short descriptions of what each is used for.

Install the code and these dependencies by running, in the project root directory:
```bash
pip install -e .
```


<br>

## Usage

You should now be able to import the code as a package into scripts and notebooks:
```py
import voltage_to_wiring_sim as v  # example shorthand
```

The `-e` in the installation command stands for `editable`, meaning you can change the source code 
(found in [`code/voltage_to_wiring_sim/`](code/voltage_to_wiring_sim/)) 
and use the updated code in scripts without having to reinstall the package.

To allow editing of the source code while running a Jupyter notebook, run a cell with the following:
```ipython3
%load_ext voltage_to_wiring_sim.auto_reload_package
```
This allows you to update the source code without having to restart the Python 'kernel' on every change.\
(This is not foolproof yet, and a kernel restart may still be needed for certain changes.
But editing for example a module-level function should work fine).

More explanation on the code can be found in [`code/README.md`](https://github.com/tfiers/voltage-to-wiring-sim/tree/master/code#readme), and in the Python files themselves, as comments and docstrings.


<br>

## Licenses

The favicon for the website is © 2020 The Jupyter Book Community, 
licensed under [their BSD-3-clause license](https://github.com/executablebooks/jupyter-book/blob/master/LICENSE).

