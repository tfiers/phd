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
    #
    # A list of Python packages on which this package depends.
    #
    # The `~=` operator specifies that your installed packages, with versions
    # "major.minor.xyz", must have the same major version as given here, but can have a
    # higher minor version. According to semantic versioning [https://semver.org], this
    # means: your packages should have no backwards incompatible changes (i.e. this
    # package's code should keep running in your environment), but new features and
    # bugfixes are allowed in your packages. If the packages in your current environment
    # can't match these requirements, install in a new conda environment (or
    # alternatively, a new virtualenv or pipenv):
    # [https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html]
    #
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
                              # parameters. Used to safeguard against the mistakes
                              # likely to happen when manually converting units. Also,
                              # auto-adds units and signal names to plot axes.
                              # [https://unyt.readthedocs.io]
    )
)
