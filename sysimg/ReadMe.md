
This does not work: yes, in terminal it does, and PythonPlot is much faster.
But when using this as an IJulia kernel, the kernel does not start
(`Precompiling IJulia [..]
ERROR: LoadError: OutOfMemoryError()` and `Exception: EXCEPTION_ACCESS_VIOLATION at 0x7ffedc8a89ae -- jl_table_assign_bp at C:/workdir/src\iddict.c:48
in expression starting at C:\Users\tfiers\.julia\packages\IJulia\6TIq1\src\IJulia.jl:36`).


## For archival purposes:

These scripts can be used to generate a custom "system image" with PackageCompiler.jl, like [here](
https://julialang.github.io/PackageCompiler.jl/stable/examples/plots.html).

The goal is to have to wait less long for package imports and first function calls in a
fresh Julia session.


## Build

To build the image, run, in this directory:
```
julia build.jl
```
This takes 10+ minutes.


## Use

To use the generated system image:

- On the command line, in the repo root:
  ```
  julia --sysimage=sysimg/mysys.dll
  ```

- As a 'kernel' in Jupyter: see the
  [relevant IJulia docs](
    https://julialang.github.io/IJulia.jl/stable/manual/installation/#Installing-additional-Julia-kernels).  
  Make sure to also add the flag `--project=@.`.


## Notes

- If on Linux or MacOS, you can replace the `.dll` extension inside these scripts with `.so` or `.dylib` respectively (though leaving it as is will also just work).

- For me, the generated Jupyter kernel definition file is located at:  
  `C:\Users\tfiers\AppData\Roaming\jupyter\kernels\julia-mysys-1.9\kernel.json`

- A relevant / helpful project: https://github.com/terasakisatoshi/sysimage_creator
