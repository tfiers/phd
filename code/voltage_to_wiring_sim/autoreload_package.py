from importlib import reload
from inspect import getmembers, getmodule
from pathlib import Path
from types import ModuleType


import voltage_to_wiring_sim


def load_ipython_extension(ipython):
    ipython.events.register(
        "pre_execute", lambda: reload_package_if_modified(voltage_to_wiring_sim)
    )


def reload_package_if_modified(entrypoint: ModuleType):
    global prev_last_modified_time
    package_dir = Path(entrypoint.__spec__.submodule_search_locations[0])
    module_files = package_dir.glob("**/*.py")
    last_modified_time = max([f.stat().st_mtime for f in module_files])
    print(last_modified_time, prev_last_modified_time)
    if last_modified_time > prev_last_modified_time:
        prev_last_modified_time = last_modified_time
        reload_package(entrypoint)


def reload_package(entrypoint: ModuleType):
    """
    Follows the import tree from the `entrypoint` module -- but only to modules that
    belong to the same package. Reloads all such modules in depth-first order.
    """

    visited_modules = set()

    def visit(module):
        if module in visited_modules:
            return
        else:
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
