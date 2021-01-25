import reprlib
from contextlib import contextmanager
from dataclasses import asdict, fields
from textwrap import fill
from time import time


@contextmanager
def time_op(description: str, end="\n"):
    bprint(f"{description}: ", end="")
    t0 = time()
    yield
    dt = time() - t0
    duration_str = f"[{dt:.2f} s]"
    bprint(f"{duration_str:<8}", end=end)


def with_progress_meter(sequence, description=None, end="\n"):
    # We don't use the standard solution, `tqdm`, as it adds a trailing newline and can
    # thus not be integrated in a gradual, one-line printing context.
    if description:
        bprint(f"{description}: ", end="")
    total = len(sequence)
    for i, item in enumerate(sequence):
        meter_str = f"{i}/{total}"
        bprint(meter_str, end="")
        yield item
        bprinter.backspace(len(meter_str))
    bprint(f"{total}/{total}", end=end)


class BackspaceablePrinter:
    # Printing backspace characters (`\b`) does not work in Jupyter Notebooks
    # [https://github.com/jupyter/notebook/issues/2892].
    # Hence we emulate it by erasing the entire line (which does work), and reprinting
    # what was already there. The goal? Progress meters (see `with_progress_meter`).

    def __init__(self):
        self.last_line = ""

    def print(self, msg: str, end="\n"):
        """ Use if you want to be able to later backspace in the same line. """
        full_msg = msg + end
        if "\n" in full_msg:
            self.last_line = full_msg.split("\n")[-1]
        else:
            self.last_line += full_msg
        print(full_msg, end="", flush=True)

    def backspace(self, num=1):
        self.last_line = self.last_line[:-num]
        print(f"\r{self.last_line}", end="")
        # This is the exact incantation :p. Cannot `flush` or print line in new `print`.


bprinter = BackspaceablePrinter()
bprint = bprinter.print


def pprint(dataclass, values=True):
    """
    Pretty-prints a dataclass as a table of its fields and their values, and with the
    class name as header.
    """

    ddict = asdict(dataclass)
    len_longest_name = max(len(name) for name in ddict.keys())

    dataclass_name = dataclass.__class__.__name__
    header_lines = [
        dataclass_name,
        "-" * len(dataclass_name),
    ]

    def pprint(value):
        if isinstance(value, float):
            return format(value, ".4G")
        else:
            return fill(
                reprlib.repr(value),  # reprlib abbreviates long lists
                subsequent_indent=(len_longest_name + 4) * " ",
            )

    if values:
        content_lines = [
            f"{name:>{len_longest_name}} = {pprint(value)}"
            for name, value in ddict.items()
        ]
    else:
        content_lines = [
            f"{field.name:<{len_longest_name}}: {field.type}"
            for field in fields(dataclass)
        ]

    print("\n".join(header_lines + content_lines))