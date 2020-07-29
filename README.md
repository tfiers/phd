# ⚡ Voltage-to-wiring 🕸 • The simulation

In vivo connectomics -- mapping the wires between neurons based on voltage imaging recordings. Proof of concept simulation.

👉 Website with rendered notebooks & documentation: https://tfiers.github.io/voltage-to-wiring-sim

(There's some text below that is out of date).

## How to navigate this project

 - The [`notebooks`](/notebooks) directory contains a list of past "reports" / analyses.
   Each is a mix of text, figures, and some code.    <br><br>
   View: [![nbviewer](https://raw.githubusercontent.com/jupyter/design/master/logos/Badges/nbviewer_badge.svg)](https://nbviewer.jupyter.org/github/tfiers/voltage_wiring_sim/tree/master/notebooks/)  
   Interact: [![Binder](https://notebooks.gesis.org/binder/badge_logo.svg)](https://notebooks.gesis.org/binder/v2/gh/tfiers/voltage_wiring_sim/master/)
    <details>
      <ul>
        <li>These are <a href="https://jupyter.org/">Jupyter Notebooks</a>, which are JSON files that need an app to be rendered in human-friendly form.
        <li>Nbviewer renders static versions of the notebooks, online.</li>
          <ul><li>The notebooks can also be viewed directly on GitHub, but that takes longer to load and yields more rendering errors, eg in LaTeX formulas.
          </ul></li>
        <li>Binder can run the notebooks in the cloud, for interactive exploration.
          <ul>
            <li>Binder often does not work. When it does however, it works very well 
              (it automatically installs packages found in `requirements.txt` and correctly imports code from the sibling `code` directory.)</li>
            <li>For each new commit to GitHub, a new Docker image needs to be created for this project on the Binder server.
              Therefore, the first time the Binder app is launched after a new commit, startup will be slower than for subsequent launches.</li>
            <li>Any edits made in the code or the notebooks in a running Binder server will not be persisted to this repository.</li>
          </ul></li>
        <li>You can also of course clone this repository to your local machine and run a local Jupyter server, 
          to view and interact with the notebooks and the code.
          There is a guide on how to do this below ("Technical details" > "Local setup guide").</li>
        <li>Google Colab does not play well with non-self-contained notebooks
          (i.e. those needing custom dependencies and, especially, loading code from Python files outside the notebook).
          Hence we do not use it, despite its boons.</li>
      </ul>
    </details>
    
 - The [`code`](/code) directory contains the simulation and analysis code used in the notebooks.
   <details>
     <summary>On old notebooks & code versions</summary>
     Past notebooks will be based on old versions of the Python files in the `code` directory.<br>
     To see the code that was responsible for a particular notebook, on GitHub, click the commit message
     next to the notebook's name in the <a href="/notebooks">directory listing</a>. Then click on the "Browse files" button.
     This shows the entire repository (including the code) as it was when the notebook was last modified.<br>
     To do this locally (and run old code versions),
     find the old commit using <code>git log notebooks/{filename}.ipynb</code>
     and temporarily turn back time with <code>git checkout {old commit's hash}</code>.
     </details>


## Neuron model

Model and parameters are from Humphries 2006, "Understanding and using
Izhikevich's simple model neuron".


## Technical details

The code is written in Python 3.8.
<details><summary>Local setup from scratch</summary>
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

The code depends on some external packages.
A list of them and short descriptions of what they are used for can be found in [`code/setup.py`](code/setup.py).  

Install the code and its dependencies by running, in the project root directory:
```bash
pip install -e code
```
This will allow you to import the code as a package into scripts and notebooks:
```py
import voltage_to_wiring_sim as v  # example shorthand
```

The `-e` in the installation command stands for `editable`, meaning you can change the source code (found in [`code/voltage_to_wiring_sim/`](code/voltage_to_wiring_sim/)) and use the updated code in scripts without having to reinstall the package.

To allow editing of the source code while running a Jupyter notebook, run a cell with the following:
```
%load_ext voltage_to_wiring_sim.autoreload_package
```
This allows you to update the source code without having to restart the Python 'kernel' on every change.


More explanation on the code can be found in [`code/README.md`](code/README.md), and in the Python files themselves, as comments and docstrings.

## Licenses

The favicon for the website is © 2020 The Jupyter Book Community, licensed under [their BSD-3-clause license](https://github.com/executablebooks/jupyter-book/blob/master/LICENSE).
