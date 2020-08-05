try:
    from IPython.lib.pretty import PrettyPrinter
except ModuleNotFoundError:
    # IPython is not a required dependency, so no worries if not installed.
    pass


def _make_ipython_print_str(self, p: PrettyPrinter, _cycle: bool):
    """
    IPython (in a Jupyter notebook eg) by default prints an object's `__repr__` when
    representing it. Use this method to have it print the object's `__str__` instead.
    
    To do this, define an attribute `_repr_pretty_` on the object, and point it to this
    function.
    
    For more info, see "Integrating your objects with IPython" in the IPython docs.
    [https://ipython.readthedocs.io/en/stable/config/integrating.html]
    """
    p.text(str(self))
