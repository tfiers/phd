from setuptools import find_packages, setup

setup(
    name="pyplotlib",
    version="0.1",
    python_requires=">= 3.6",
    install_requires=["matplotlib >= 3.7"],
    packages=find_packages("src"),
    package_dir={"": "src"},  # (`""` is the "root" package).
)
