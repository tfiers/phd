from setuptools import setup, find_packages

SOURCE_DIR = "codebase"


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
    # have a higher minor version.
    #
    # If the packages in your current environment can't match these
    # requirements, install in a new conda environment:
    # [https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html]
    # (or alternatively, a new virtualenv or pipenv).
    #
    # fmt: off
    install_requires=(
        "numpy ~= 1.18",       # Fast numeric arrays and functions to generate/
                               # manipulate them. [https://numpy.org]
        "matplotlib ~= 3.1",   # Plotting. [https://matplotlib.org]
        "numba ~= 0.50",       # Speeds up custom numeric calculations, such as the
                               # Izhikevich ODE integration. Given a Python function,
                               # Numba assumes the function only processes numeric
                               # arrays (and not arbitrary, general purpose Python
                               # objects), so that it can compile it to lean machine
                               # code (instead of having to invoke the powerful-but-slow
                               # Python interpreter on every line). It so approaches
                               # C or Julia performance. [http://numba.pydata.org]
        # "unitlib",             # Physical units for quantities, such as neuron model
                               # parameters. Used to safeguard against the mistakes
                               # likely to happen when manually converting units. Also,
                               # auto-adds units and signal names to plot axes.
                               # [https://github.com/tfiers/unitlib]
        # "joblib ~= 0.16",      # (Currently unused).
                               # [https://joblib.readthedocs.io/]
        "seaborn ~= 0.11",     # Extension of Matplotlib for statistical data viz.
                               # [https://seaborn.pydata.org/]
        "scipy ~= 1.5",        # Numerical utilities (peak finding, integration,
                               # interpolation, optimisation, ...).
                               # [https://docs.scipy.org/doc/scipy/reference/]
        "scikit-learn ~= 0.23",# Machine learning (used for kernel density estimation).
                               # [https://scikit-learn.org/]
        "preload ~= 2.1",      # Print what's happening during slow imports.
                               # [https://github.com/tfiers/preload]
        "nptyping ~= 1.3",     # Type hints for NumPy arrays.
                               # [https://pypi.org/project/nptyping/].
        "tqdm ~= 4.55",        # Progress meter & timing info for slow loops.
                               # [https://github.com/tqdm/tqdm].
    )
)
