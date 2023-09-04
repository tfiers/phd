from joblib import Memory

disk = Memory(".")

# Hack to be able to use Joblib in a Jupyter notebook,
# by overwriting the default `__main__` module by a custom identifier.
def cache(module, **joblib_kwargs):
    def cache_(f):
        f.__qualname__ = f.__name__
        f.__module__ = module
        return disk.cache(f, **joblib_kwargs)
    return cache_
