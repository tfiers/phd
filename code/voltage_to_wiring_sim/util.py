from contextlib import contextmanager
from time import time


@contextmanager
def report_duration(action_description: str):
    print(action_description, end=" … ")
    t0 = time()
    yield
    duration = time() - t0
    print(f"✔ ({duration:.2g} s)")
