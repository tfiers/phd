# Executing code

You can not only read the notebooks on this website, you can also run them and play with the data inside.

There are two ways to do this:

1. Locally on your computer.
2. In the cloud, without having to install anything.


## Running locally

See this repository's [README](https://github.com/tfiers/voltage-to-wiring-sim#readme) for installation instructions.


(running-in-the-cloud)=
## Running in the cloud

The technology making this possible is called '[Binder](https://mybinder.org/)'.

````{margin}
```{caution}
Don't rely on a Binder server for anything you want to last – each session is terminated after a short period of inactivity.
```
````
Each notebook on this website contains a link (behind the <i class="fas fa-rocket"></i> icon at the top of the notebook page) to launch a Binder server. Binder will check out the repository from GitHub and install all necessary dependencies, including our custom code base. When those operations are finished, you can interact with the notebook.

```{admonition} Slow launch?
:class: tip
For each new commit to the repository, a new Docker image needs to be created on the Binder server. Therefore, the first time the Binder app is launched after a new commit, startup will be slower than for subsequent launches.
```
```{admonition} Why not Google Colab?
:class: tip
Google Colab does not play well with non-self-contained notebooks; i.e. those needing custom dependencies and, especially, loading code from Python files outside the notebook. Hence we do not use it, despite its boons.
```


## Jupyter notebook tips

This is a short overview of tricks.\
For a full treatment, see the first chapter of Jake VanderPlas's excellent "Python for Data Science Handbook", which is freely available online [here](https://jakevdp.github.io/PythonDataScienceHandbook/#Table-of-Contents). (That chapter describes IPython. IPython is the project out of which Jupyter grew, and the current main technology behind Jupyter Python notebooks).

Onto the tips.

### Object inspection
With the cursor in a code cell:
 - Use `tab` for a list of available objects, and for completion of partially typed names.
 - Use `shift-tab` with the cursor on a Python object to get help on that object (eg a method's call signature and docstring).

Another way to get help on an object is to prepend its name by `?`, and then run the cell:
```
?np
```
This can also be used to get help on IPython 'magics' (see {ref}`below <debugging>` for examples of magics):
```
?%%prun
```

Two question marks yield the source code of an object:
```
??v.neuron_sim.simulate_izh_neuron
```


(debugging)=
### Debugging
After a code crash, run a cell containing `%debug` to enter a debugger in post-mortem mode, allowing you to inspect variables in your crashed code. In this debugger, type `h` for a list of possible commnds. (Eg. `u` takes you up one frame in the stack trace).


(timing-and-profiling)=
### Timing and profiling

A code block can be profiled using the cell magic `prun`:
```ipython
%%prun
# [slow code]
```
This will show, for each called function, the total time spent in that function (`cumtime`), and the total time spent in that function minus time spent in subcalls (`tottime`).
For a graphical overview of this profile, including an estimated call graph ("which function called which?"), install [snakeviz](https://jiffyclub.github.io/snakeviz/), and use `%%prun -D temp.profile`. Then, in a shell, run
```bash
snakeviz temp.profile
```

Two more useful magics:
- `$$time` simply measures the run duration of a code block.
- `$$timeit` repeatedly runs a code block to get accurate timing measurements and statistics.
