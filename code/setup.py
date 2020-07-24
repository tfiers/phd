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
)
