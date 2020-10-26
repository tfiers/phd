## Some explanations on what you might encounter in the code

### Type hints
I sometimes add type hints to code (Python is an optionally typed language).  
These look like eg `t: unyt_array = ...`  
("variable `t` is of type `unyt_array`").  
I do this to get code completions in my IDE (namely PyCharm) when
the IDE cannot infer the type of a variable automatically.

### `fmt: off`
I use an auto-formatter ("[Black](https://black.readthedocs.io/)") to automatically
format code on save. Sometimes I want to keep manual formatting though (when manually
aligning comments or unit definitions, eg). This directive tells Black to leave the
formatting below it as is.
