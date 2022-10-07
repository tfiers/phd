These scripts can be used to generate a custom "system image" with PackageCompiler.jl, like [here](
https://julialang.github.io/PackageCompiler.jl/stable/examples/plots.html).

The goal is to have to wait less long for package imports and first function calls in a
fresh Julia session.


## Build

To build the image, run, in this directory:
```
julia build.jl
```
This takes a few minutes.


## Use

To use the generated system image:

- On the command line, in the repo root:
  ```
  julia --sysimg=sysimg/mysis.dll
  ```

- As a 'kernel' in Jupyter: see the
  [relevant IJulia docs](
    https://julialang.github.io/IJulia.jl/stable/manual/installation/#Installing-additional-Julia-kernels).  
  Make sure to also add the flag `--project=@.`.


## Notes

- If on Linux or MacOS, you can replace the `.dll` extension inside these scripts with `.so` or `.dylib` respectively (though leaving it as is will also just work).

- For me, the generated Jupyter kernel definition file is located at:  
  `C:\Users\tfiers\AppData\Roaming\jupyter\kernels\julia-mysis-1.8\kernel.json`

- The packages included in `Project.toml` where those imported in `MyToolbox.jl` with the slowest slowest load times.

- `repl_trace.jl` was generated like [here](https://julialang.github.io/PackageCompiler.jl/dev/examples/ohmyrepl.html), i.e. with `julia --trace-compile=repl_trace.jl`.
  In [my julia startup script](https://github.com/tfiers/dotfiles/blob/main/.julia/config/startup.jl), OhMyREPL was imported and configured.
