## On `if TYPE_CHECKING`

`TYPE_CHECKING` is `False` at runtime (so we don't get circular imports), but the
imports within the if-statement let the editor (PyCharm) resolve type annotations.
See [PEP 563](https://www.python.org/dev/peps/pep-0563/#runtime-annotation-resolution-and-type-checking).
