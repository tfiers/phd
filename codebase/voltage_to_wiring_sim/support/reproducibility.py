import sys
from datetime import datetime
from functools import partial
from getpass import getuser
from platform import platform, python_implementation, python_version
from socket import gethostname
from subprocess import run

from cpuinfo import get_cpu_info


REPO_URL = "https://github.com/tfiers/voltage-to-wiring-sim"


timezone = datetime.now().astimezone().tzinfo  # Weird that this long hack is necessary,
#                                              # Python stdlib.

try:
    # noinspection PyUnresolvedReferences
    from IPython.core.display import display_markdown

    print_md = partial(display_markdown, raw=True)
    
except ImportError:
    print_md = print


def print_reproducibility_info(verbose=False):
    """
    Print info on execution environment, to make archaeology easier.
    Meant to be run in IPython / a Jupyter Notebook.
    Based on https://github.com/rasbt/watermark.
    """
    print_when_who_where()
    print_last_commit_link()
    print_git_status()
    if verbose:
        print_platform_info()
        print_package_versions()


def print_when_who_where():
    now = datetime.now(timezone)
    print_md(
        f"This cell was last run by `{getuser()}` on `{gethostname()}`<br>"
        f"{now:on **%a %d %b** %Y, at %H:%M (UTC%z)}."
        #   See [https://docs.python.org/3/library/datetime.html#strftime-and-strptime-format-codes]
    )


def print_last_commit_link():
    last_commit_hash = get_cmd_output("git rev-parse HEAD")
    last_commit_timestamp = get_cmd_output("git log -1 --format=%at")
    last_commit_datetime = datetime.fromtimestamp(int(last_commit_timestamp), timezone)
    print_md(
        f"[Last git commit]({REPO_URL}/tree/{last_commit_hash}) "
        f"({last_commit_datetime:%a %d %b %Y, %H:%M})."
    )


def print_git_status():
    git_root_dir = get_cmd_output("git rev-parse --show-toplevel").strip()
    git_status = get_cmd_output("git status -s", cwd=git_root_dir)
    if git_status.strip() == "":
        print_md("No uncommitted changes")
    else:
        print_md(f"Uncommited changes to:\n```\n{git_status}```")


def print_platform_info():
    print_md("Platform:")
    print(f"{platform(terse=True)}")  # OS
    print(f"{python_implementation()} {python_version()} ({sys.executable})")
    print(get_cpu_info()["brand_raw"])  # Takes a sec.


def print_package_versions():
    root_package_name = __package__.split(".")[0]
    print_md(f"Dependencies of `{root_package_name}` and their installed versions:")
    deps = get__pip_show__value(root_package_name, "Requires: ").split(", ")
    for package_name in deps:
        print(format(package_name, "<20"), end=" ")
        version = get__pip_show__value(package_name, "Version: ")
        print(version)


def get_cmd_output(cmd, **kwargs) -> str:
    # We don't use `check_output`, as that function raises an error on non-zero return
    # codes. `run` does not. (`pip show unitlib` returns code 120).
    kwargs.update(capture_output=True, text=True)
    completed_process = run(cmd.split(), **kwargs)
    return completed_process.stdout


def get__pip_show__value(package_name: str, key: str) -> str:
    for line in get_cmd_output(f"pip show {package_name}").splitlines():
        if line.startswith(key):
            return line[len(key) :]
        else:
            continue
