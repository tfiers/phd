from importlib import reload
from inspect import getmembers, getmodule
from pathlib import Path
from types import ModuleType

import voltage_to_wiring_sim


class PackageAutoReloader:
    def __init__(self, entrypoint: ModuleType, max_retries=8):
        self.entrypoint = entrypoint
        self.mtime_at_last_interaction = self.get_mtime()
        self.max_retries = max_retries

    def get_mtime(self):
        """ Last time when any of the Python files in the package were modified. """
        package_dir = Path(self.entrypoint.__spec__.submodule_search_locations[0])
        module_paths = package_dir.glob("**/*.py")
        return max([path.stat().st_mtime for path in module_paths])

    def reload_package_if_modified(self):
        if (mtime := self.get_mtime()) > self.mtime_at_last_interaction:
            self.reload_package()
        self.mtime_at_last_interaction = mtime

    def reload_package(self):
        """
        Follows the import tree from the `entrypoint` module -- but only to modules that
        belong to the same package. Reloads all such modules in depth-first order.
        """
        visited_modules = set()
        any_errors = False

        def visit(module):
            global any_errors
            if module in visited_modules:
                return
            else:
                visited_modules.add(module)
                if module.__package__.startswith(self.entrypoint.__package__):
                    for name, object in getmembers(module):
                        if (source_module := getmodule(object)) :
                            visit(source_module)
                    try:
                        reload(module)
                        print(f"Reloaded {module.__name__}")
                    except ModuleNotFoundError:
                        any_errors = True

        for _ in range(self.max_retries):
            visit(self.entrypoint)
            if any_errors:
                any_errors = False
                continue
            else:
                break


def load_ipython_extension(ipython):
    autoreloader = PackageAutoReloader(voltage_to_wiring_sim)
    ipython.events.register("pre_execute", autoreloader.reload_package_if_modified)
