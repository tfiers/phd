# Voltage-to-wiring, the simulation

In vivo connectomics -- mapping the wires between neurons based on voltage imaging recordings.\
Proof of concept simulation.

For rendered notebooks with results: &nbsp; [![](https://img.shields.io/badge/%F0%9F%9A%80_open_website-green)](https://tfiers.github.io/voltage-to-wiring-sim)


<br>

The code was initially written in Python, and later in Julia.

- `notebooks/` contains Jupyter Notebooks, both in Python and later, from 2022 on, in Julia. These notebooks draw and store figures, and call functions from an external codebase:
- `julia-codebase/` is the main codebase. `JuliaProject.toml` and `JuliaManifest.toml` show the required & exact installed Julia packages.
- `python-codebase/` is the deprecated Python codebase. `setup.py` shows the required Python packages, and the "Reproducibility" sections in Python notebooks show the exact installed pip and conda packages.
- `website/` contains config and code to build the [website](https://tfiers.github.io/voltage-to-wiring-sim) where the notebooks are hosted as a [JupyterBook](https://jupyterbook.org/).


## Julia

To reproduce results (i.e. run one of the notebooks):

- You need a version of Julia ∈ [1.7, 2). [Download](https://julialang.org/downloads/) and run an installer for your OS if needed.
- Choose a Julia notebook to run. Copy the hash of the last commit to the notebook file. (A link to this commit and its hash can be found next to the notebook's filename in the [`notebooks/`](notebooks/) directory on GitHub).
  - Why do we need this commit? The codebase that is called from the notebook will have been further developed since the notebook was last run (unless you chose one of the most recent notebooks). Checking out the commit (next step) restores the codebase to its former, working state for the notebook.
- `git clone` this repository. `git checkout` the copied commit hash.
- In the root directory, enter Julia [Pkg mode](https://docs.julialang.org/en/v1/stdlib/REPL/#Pkg-mode).
  Then run `activate .` (note the dot) and `instantiate` to install all dependencies.
  This might need a shell with admin access.
- Start a Jupyter server.
  - If you don't have Jupyter installed, run `using IJulia` and `notebook()` in the julia repl.
  - If you have, the usual `jupyter notebook` in the terminal works.

You should now be able to run all cells in the notebook.



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
— found in [`python-codebase/voltage_to_wiring_sim/`](python-codebase/voltage_to_wiring_sim/) — 
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


More explanation on the code can be found in the [Python files](python-codebase/voltage_to_wiring_sim/) 
themselves, as comments and docstrings.


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

## Licences

The favicon for the website is © 2020 The Jupyter Book Community, 
licensed under [their BSD-3-clause licence](https://github.com/executablebooks/jupyter-book/blob/master/LICENSE).
