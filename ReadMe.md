# ⚡ Voltage –> wiring 🕸 – The simulation

In vivo connectomics -- mapping the wires between neurons based on voltage imaging recordings. Proof of concept simulation.


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
<details><summary>Local setup guide</summary>
To setup your local machine for running this project, I recommend the <a href="https://docs.conda.io/">conda</a> package manager,
specifically its small <a href="https://docs.conda.io/en/latest/miniconda.html">miniconda</a> installer.<br>
Installing conda will also install Python, and the `pip` Python package installer used below.<br>
If Python's version is not already at least 3.8 (checked with <code>python --version</code>),
upgrade using <code>conda update python</code>.<br>
After cloning this repository, run <code>pip install -r requirements.txt</code> in the project's root directory,
to install the external packages on which the code depends.
Finally, you can run <code>python -m notebook</code>. This will open the Jupyter app locally, in your browser,
in which you can play with the notebooks that run the simulation/analysis code and display the results.
</details>

The code depends on some external packages.
A list of them and short descriptions of what they are used for can be found in [`requirements.txt`](/requirements.txt).

I sometimes add type hints to code (Python is an optionally typed language).  
These look like eg `t: unyt_array = ...`  
("variable `t` is of type `unyt_array`").  
I do this to get code completions in my IDE (namely PyCharm) when
the IDE cannot infer the type of a variable automatically.
