from setuptools import setup, find_packages

SOURCE_DIR = "code"


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
    package_dir={"": SOURCE_DIR},
    packages=find_packages(where=SOURCE_DIR),
    #
    # A list of Python packages on which this package depends.
    #
    # The `~=` operator specifies that your installed packages, with versions
    # "major.minor.xyz", must have the same major version as given here, but can
    # have a higher minor version. (See [https://semver.org] for what this means
    # for 'allowed' differences between your packages and the packages with
    # which this code was developed).
    #
    # If the packages in your current environment can't match these
    # requirements, install in a new conda environment:
    # [https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html]
    # (or alternatively, a new virtualenv or pipenv).
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
        "multipledispatch ~= 0.6",  # Used in `unyt_mod.py` to call a different version
                              # of `as_raw_data()` depending on the input type.
                              # [https://pypi.org/project/multipledispatch]
        "toolz ~= 0.10",      # `valmap` to apply a function to a dictionary's values.
                              # [https://github.com/pytoolz/toolz]
        "joblib ~= 0.16",     # (Currently unused).
                              # [https://joblib.readthedocs.io/]
        "preload ~= 2.1",     # Preload heavy imports, with user feedback.
                              # [https://github.com/tfiers/preload]
    )
)
