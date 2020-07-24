from importlib import reload
from inspect import getmembers, getmodule
from types import ModuleType


import voltage_to_wiring_sim


def load_ipython_extension(ipython):
    ipython.events.register(
        "pre_execute", lambda: reload_package(voltage_to_wiring_sim)
    )


def reload_package(entrypoint: ModuleType):
    """
    Follows the import tree from the `entrypoint` module -- but only to modules that
    belong to the same package. Reloads all such modules in depth-first order.
    """

    visited_modules = set()

    def visit(module):
        if module not in visited_modules:
            visited_modules.add(module)
            if module.__package__.startswith(entrypoint.__package__):
                for name, object in getmembers(module):
                    if (source_module := getmodule(object)) :
                        visit(source_module)
                        
                reload(module)
                print(f"Reloaded {module.__name__}")

    # print(f"Reloading package `{entrypoint.__package__}`", end="...")
    visit(entrypoint)
    # print("Done")
