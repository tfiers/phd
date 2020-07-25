from setuptools import setup, find_packages

setup(
    name="voltage_to_wiring_sim",
    version="0.1",
    description=(
        "Proof of concept simulation for in vivo connectomics: "
        "mapping the wires between neurons based on voltage imaging recordings."
    ),
    url="https://github.com/tfiers/voltage-to-wiring-sim",
    author="Tomas Fiers",
    author_email="tomas.fiers@gmail.com",
    license="MIT",
    packages=find_packages(),
    # fmt: off
    install_requires=(
        "numpy ~= 1.18",      # Fast numeric arrays and functions to generate/manipulate
                              # them. [https://numpy.org]
        "matplotlib ~= 3.1",  # Plotting. [https://matplotlib.org]
        "numba ~= 0.50",      # Speeds up custom numeric calculations, such as the
                              # Izhikevich ODE integration. Given a function, Numba
                              # assumes the function only processes numeric arrays (and
                              # not arbitrary, general purpose Python objects), so that
                              # it can compile it to lean machine code (instead of
                              # having to invoke the powerful-but-slow Python
                              # interpreter on every line). [http://numba.pydata.org]
        "unyt ~= 2.7",        # Physical units for quantities, such as neuron model
                              # parameters and time grids. Used to safeguard against the
                              # mistakes likely to happen when manually converting
                              # units. Also, auto-adds units and signal names to plot
                              # axes. [https://unyt.readthedocs.io]
    )
)
