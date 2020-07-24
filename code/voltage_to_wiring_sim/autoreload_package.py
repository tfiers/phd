from importlib import reload
from types import ModuleType

import voltage_to_wiring_sim


def load_ipython_extension(ipython):
    ipython.events.register(
        "pre_execute", lambda: reload_package(voltage_to_wiring_sim)
    )


def reload_package(main_module: ModuleType):
    """
    Follows the import tree from `main_module` -- but only to imported modules that
    belong to the same package. Reloads all such modules in depth-first order.
    """

    visited_modules = set()

    def visit(module):
        if (
            module.__package__.startswith(main_module.__package__)
            and module not in visited_modules
        ):
            visited_modules.add(module)
            for name in dir(module):
                obj = getattr(module, name)
                if isinstance(obj, ModuleType):
                    visit(obj)
            reload(module)
            print(f"Reloaded {module.__name__}")

    visit(main_module)
