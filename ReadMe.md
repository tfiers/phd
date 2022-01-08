# Voltage-to-wiring, the simulation

In vivo connectomics -- mapping the wires between neurons based on voltage imaging recordings.\
Proof of concept simulation.

For rendered notebooks with results: &nbsp; [![](https://img.shields.io/badge/%F0%9F%9A%80_open_website-green)](https://tfiers.github.io/voltage-to-wiring-sim)


<br>

The code was initially written in Python, and later in Julia.
- `src/` is the Julia codebase, and `Project.toml` and `Manifest.toml` show the required & exact installed Julia packages.
- `codebase/` is the Python codebase, `setup.py` shows the required Python packages, and the "Reproducibility" sections in python notebooks show the exact installed Python  packages.
- `notebooks/` contains all Jupyter Notebooks, both in Python and, later, in Julia.
- `website/` contains config and code to build the website where the notebooks are hosted as a JupyterBook.


## Julia

To reproduce results:

- If new to Julia, [download](https://julialang.org/downloads/) and run its installer for your OS.
- Clone this repo, and in the root directory, enter Julia [Pkg mode](https://docs.julialang.org/en/v1/stdlib/REPL/#Pkg-mode).
  Then run `activate .` and `instantiate` to install all dependencies.
- Start a Jupyter server.
  - If you don't have Jupyter installed, run `using IJulia` and `notebook()` in the julia repl.
  - If you have, the usual `jupyter notebook` in the terminal works.
- Open one of the Julia `notebooks/` (from 2022 on).
  - If it is not one of the newest notebooks, the codebase will have changed since the notebook was last run. To restore the codebase to its former state, find the commit of the last change to the notebook (shown on GitHub), and `git checkout` this commit.

You should now be able to run all cells



## Python

### Installation

The code is written in Python 3.9.

<details><summary>[How to install Python and Jupyter, using 'conda']</summary>
To setup your local machine for running this project, I recommend the <a href="https://docs.conda.io/">conda</a> package manager,
specifically its small <a href="https://github.com/conda-forge/miniforge">miniforge</a> installer.<br>
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

### Usage

You should now be able to import the code as a package into scripts and notebooks:
```py
import voltage_to_wiring_sim as v  # example shorthand
```

Get going quickly in a Jupyter notebook (or an IPython REPL session), by running:

```py
from voltage_to_wiring_sim.notebook_init import *
```
This imports useful packages (`numpy as np`, `voltage_to_wiring_sim as v`, etc), and 
configures IPython (like enabling `%autoreload`, 'retina' figures, nice number formatting, etc).


More explanation on the code can be found in the [Python files](codebase/voltage_to_wiring_sim/) 
themselves in, as comments and docstrings.


<br>

### Tests

Some modules contain small `test()` functions to showcase how the module is used.

Instructions on how to run/debug these in PyCharm:
1. Create a scratch file.
2. In it, `import voltage_to_wiring_sim as v` and call `v.synapses.test()`, e.g.
3. Run/debug this scratch file.

To run them in a notebook, just do the second step. 

> The reason for this verbosity is that modules shouldn't be run as scripts (it's also not
easy -- it errors e.g. on relative imports) -- but I still wanted my test code to be
close to the code that it's testing/showcasing.

These test functions are also run automatically on every push of code to GitHub
([results](https://github.com/tfiers/voltage-to-wiring-sim/actions?query=workflow%3ACI),
[workflow file](https://github.com/tfiers/voltage-to-wiring-sim/blob/main/.github/workflows/CI.yml)).
This is not a test of the scientific correctness of the code (there are no `assert`
statements). Rather, it is a check that the code still runs without runtime errors after
introducing changes to it (i.e. it's a smoke test or integration test).


<br>

## Licenses

The favicon for the website is © 2020 The Jupyter Book Community, 
licensed under [their BSD-3-clause license](https://github.com/executablebooks/jupyter-book/blob/master/LICENSE).
