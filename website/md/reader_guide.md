# Guide to the reader

The way this website is organised follows from my research workflow.


## Workflow

 1. Whenever I want to test something or prototype new work, I do this in a new [Jupyter notebook](https://jupyter.org/). You can browse past such notebooks under the "Unpolished notebooks" folder in the menu.
 2. Notebooks wrought into proper reports, meant to be read by supervisors and ready for feedback, are moved to the "Reports" folder.
 3. I regularly write code that I want to re-use in multiple future notebooks. I integrate all such code in one codebase (external to the notebooks), which can be browsed [here on GitHub](https://github.com/tfiers/voltage-to-wiring-sim), in the `code` directory. This code is imported as a Python package into notebooks.


## Past notebooks & old code versions

The codebase thus gradually grows and changes. As a result, past notebooks will not 'work' anymore with the newest code version.
The notebook will use functions and modules that have been renamed or don't exist anymore, and executing the notebook will yield an error.

```{margin}
See {doc}`/md/executing_code` for info on Binder.
```
Hence, I will try to mention in each notebook with which version of the codebase it was last run succesfully.
This 'version' will be a git commit. I will provide links to GitHub and Binder pages
where the repository is rolled back to that commit,
so that the source code can be viewed, and the notebook executed, at that point in history.


## Giving feedback in context

When you select some text on any page of this website, there should appear a popover that allows you to write a comment on that text.
This will open a right sidebar prompting you to login to [Hypothesis](https://web.hypothes.is/about/), a tool for making shared annotations on the web.

The Hypothesis sidebar also allows you to make page-wide notes, and to see and reply to others' annotations.

Hypothesis annotations belong to a 'group'. By default, they go in the 'Public' group.
I made a private group for this project, which you can join [here](https://hypothes.is/groups/GNPzGXJn/voltage-to-wiring).
