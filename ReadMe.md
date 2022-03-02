# Voltage-to-wiring, the simulation

*In-vivo* connectomics — mapping the wires between neurons based on voltage imaging recordings.  
Proof of concept simulation.

For rendered notebooks with results:
> [![Button saying "go to website"](https://img.shields.io/badge/🚀_go_to_website-blue)](https://tfiers.github.io/voltage-to-wiring-sim)


## Organization

- [`nb/`](nb) contains Jupyter Notebooks with exploratory and figure-producing code, both in Python, 
  and later – from 2022 onwards – in Julia. These notebooks call code that has been factored out to external packages:
- [`pkg/`](pkg) contains Julia packages that define types and functions reused in multiple notebooks.
- [`web/`](web) contains config and code to build the [website](https://tfiers.github.io/voltage-to-wiring-sim) 
  where the notebooks are hosted as a [JupyterBook](https://jupyterbook.org/).
- [`Project.toml`](Project.toml) lists the names of the Julia packages our code directly depends on.  
  `Manifest.toml` records the exact versions of all packages used to generate the results (i.e. the notebook outputs).  
  `setup.jl` is used to generate a new `Manifest.toml`, both for the main project and for the packages in `pkg/`.
  It is only to be used when working on this codebase; not when you want to reproduce the results.


## Reproducing results

### Julia

To reproduce results, *i.e.* to succesfully run one of the notebooks:

1. You need a version of Julia `∈ [1.7, 2)`.  
  [Download](https://julialang.org/downloads/) and run an installer for your OS if needed.

2. <details><summary>
   
   `git clone` this repository with the `--recurse-submodules` option,  
   and `cd` into the new directory.
   </summary>

   `--recurse-submodules` makes sure that the git submodules 
   in this repository (see [`pkg/`](pkg/)) are cloned as well.
   </details>

3. <details><summary>
   
   Choose a Julia notebook to run.  
   If it is one of the newest notebooks, the rest of this step can be skipped.  
   If not, copy the hash of the last commit to the notebook file, and `git checkout` this commit.
   </summary>

   - A link to this commit and its hash can be found on GitHub,
     in the [`notebooks/`](notebooks/) directory, next to the notebook's filename.  
     Or use `git log <path>`.
   - Why is this step needed?
     The codebase that is called from the notebook will have been further developed 
     since the notebook was last run. Checking out the commit restores the codebase 
     to its former, working state for the notebook.
    </details>

4. <details><summary>
  
   In the root directory, enter Julia [Pkg mode](https://docs.julialang.org/en/v1/stdlib/REPL/#Pkg-mode).  
   Then run `activate .` (note the dot) and `instantiate` to install all dependencies.  
   This might need a shell with admin access.
   </summary>
   
   - `instantiate` installs the exact package versions specified in `Manifest.toml`, 
     which is included in the repository for the purpose of reproducibility.
   - If you want to instead use newer versions of dependencies,
     run `julia setup.jl` in the terminal.
   </details>

5. <details><summary>
  
   Start a Jupyter server.
   </summary>
   
   - If you do not have Jupyter installed,
     run `using IJulia` and `notebook()` in the julia REPL.
   - If you have, the usual `jupyter notebook` (or `python -m notebook`)
     in the terminal works.
   </details>

You should now be able to run all cells in the notebook.

_Last time these instructions were tested on a fresh system:_ [a few weeks before today, March 2<sup>nd</sup> 2022].


### Python

Check out an older version of the repository and its ReadMe 
for instructions on how to reproduce the older, Python notebooks:
https://github.com/tfiers/voltage-to-wiring-sim/tree/56bc7f6
