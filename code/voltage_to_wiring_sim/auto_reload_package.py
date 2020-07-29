from importlib import reload
from inspect import getmembers, getmodule
from pathlib import Path
from types import ModuleType

import voltage_to_wiring_sim
from voltage_to_wiring_sim.util import report_duration


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
                if (
                    module.__package__.startswith(self.entrypoint.__package__)
                    and module.__name__ != __name__  # don't reload ourself
                ):
                    for name, object in getmembers(module):
                        # Get module in which each object is defined, instead of just
                        # finding all names that are a module. This is to catch also
                        # `from xx import yy` modules, and not just the `import xx`
                        # modules.
                        if (source_module := getmodule(object)) :
                            visit(source_module)
                    try:
                        reload(module)
                    except ModuleNotFoundError:
                        any_errors = True

        with report_duration(f"Reloading {self.entrypoint}"):
            for _ in range(self.max_retries):
                visit(self.entrypoint)
                if any_errors:
                    any_errors = False
                    continue
                else:
                    break


autoreloader = PackageAutoReloader(voltage_to_wiring_sim)


def load_ipython_extension(ipython):
    ipython.events.register("pre_execute", autoreloader.reload_package_if_modified)


def unload_ipython_extension(ipython):
    try:
        ipython.events.unregister(
            "pre_execute", autoreloader.reload_package_if_modified
        )
    except:
        pass
