from dataclasses import dataclass


@dataclass
class Prefix:
    symbol: str
    factor: float


kilo = Prefix("k", 1e3)
deci = Prefix("d", 1e-1)
centi = Prefix("c", 1e-2)
milli = Prefix("m", 1e-3)
micro = Prefix("μ", 1e-6)
nano = Prefix("n", 1e-9)
pico = Prefix("p", 1e-12)
