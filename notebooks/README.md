# Readme

Some notebooks (eg `2020-07-05__Izhikevich_paper_accomp.ipynb`) include interactive widgets: sliders to play with the arguments of a function and see the effect in a live updated plot. Instal [Jupyter Widgets / ipywidgets](https://ipywidgets.readthedocs.io/en/latest/index.html) to make this work.

## Jupyter notebook tips

This is a short overview of tricks.\
For a full treatment, see the first chapter of Jake VanderPlas's excellent "Python for Data Science Handbook", which is freely available online [here](https://jakevdp.github.io/PythonDataScienceHandbook/#Table-of-Contents). (That chapter describes IPython. IPython is the project out of which Jupyter grew, and the current main technology behind Jupyter Python notebooks).

Onto the tips.

In a code cell:
 - Use `tab` for a list of available objects, and for completion of partially typed names.
 - Use `shift-tab` with the cursor on a Python object to get help on that object (eg a method's call signature and docstring).

A code block can be profiled using the cell magic `prun`:
```ipython
%%prun
# [slow code you want to investigate]:
# which called functions specifically are slow?
```
This will show, for each function, the total time spent in that function (`cumtime`), and the total time spent in that function minus time spent in subcalls (`tottime`).
For a graphical overview of this profile, including an estimated call graph ("which function called which?"), install [snakeviz](https://jiffyclub.github.io/snakeviz/), and use `%%prun -D temp.profile`. Then, in a shell, run
```bash
snakeviz temp.profile
```

Get help on a Python object or an IPython magic with `?`:
```ipython
?%%prun
```

Two question marks yield the source code:
```
??v.neuron_sim.simulate_izh_neuron
```
