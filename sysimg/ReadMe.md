These scripts can be used to generate a custom "system image" with PackageCompiler.jl, like [here](
https://julialang.github.io/PackageCompiler.jl/stable/examples/plots.html).

The goal is to have to wait less long for package imports and first function calls in a
fresh Julia session.


### Build
To build the image, run, in the repo root:
```
julia sysimg/build.jl
```
This takes a few minutes.


### Use

To use the generated system image:
- On the command line:
  ```
  julia --sysimg=sysimg/mysis.dll
  ```
- As a 'kernel' in Jupyter: [relevant IJulia docs](
    https://julialang.github.io/IJulia.jl/stable/manual/installation/#Installing-additional-Julia-kernels)
    - Make sure to also add the flag `"--project=@."`.
    - For me, the generated kernel definition file is located at:
      `C:\Users\tfiers\AppData\Roaming\jupyter\kernels\julia-preloaded-1.7\kernel.json`
