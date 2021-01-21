import sys
import re
from datetime import datetime
from functools import partial
from getpass import getuser
from platform import platform, python_implementation, python_version, system
from socket import gethostname
from subprocess import run
from importlib.metadata import version, requires


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
    most_important_messages = (
        get_when_who_where(verbose),
        get_last_commit_info(),
        get_git_status(verbose),
    )
    if verbose:
        for message in most_important_messages:
            print_md(message)
        print_platform_info()
        print_package_versions()
        print_conda_env()
    else:
        print_md("\n".join(most_important_messages))


def get_when_who_where(verbose):
    now = datetime.now(timezone)
    message = (
        f"This cell was last run by `{getuser()}` on `{gethostname()}`"
        f"{'<br>' if verbose else ' '}"
        f"{now:on **%a %d %b** %Y, at %H:%M (UTC%z)}."
        #   See [https://docs.python.org/3/library/datetime.html#strftime-and-strptime-format-codes]
        f"{'<br>' if not verbose else ''}"  # Newline before git info (in same md cell).
    )
    return message


def get_last_commit_info():
    last_commit_hash = get_cmd_output("git rev-parse HEAD")
    last_commit_timestamp = get_cmd_output("git log -1 --format=%at")
    last_commit_datetime = datetime.fromtimestamp(int(last_commit_timestamp), timezone)
    message = (
        f"[Last git commit]({REPO_URL}/tree/{last_commit_hash}) "
        f"({last_commit_datetime:%a %d %b %Y, %H:%M})."
    )
    return message


def get_git_status(verbose):
    git_root_dir = get_cmd_output("git rev-parse --show-toplevel").strip()
    git_status = get_cmd_output("git status -s", cwd=git_root_dir)
    if git_status.strip() == "":
        message = "No uncommitted changes."
    else:
        if verbose:
            message = f"Uncommited changes to:\n```\n{git_status}```"
        else:
            N = len(git_status.strip().split("\n"))
            message = f"Uncommited changes to {N} file{'s' if N > 1 else ''}."
    return message


def print_platform_info():
    print_md("Platform:")
    print(f"{platform(terse=True)}")  # OS
    print(f"{python_implementation()} {python_version()} ({sys.executable})")
    print(get_cpu_name())


def print_package_versions():
    root_package_name = __package__.split(".")[0]
    print_md(f"Dependencies of `{root_package_name}` and their installed versions:")
    deps = [_extract_package_name(line) for line in requires(root_package_name)]
    for package_name in deps:
        print(format(package_name, "<20"), end=" ")
        print(version(package_name))


def print_conda_env():
    print_md("Full conda list:")
    conda_list_output = get_cmd_output("conda list")
    print_md(f"```\n{conda_list_output}```")
    #   print_md (instead of plain `print`) gives 'syntax highlighting' i.e. purty
    #   colors for version numbers and 'commented out' header.


def _extract_package_name(requirement_line):
    # Examples of 'requires' lines:
    #   numpy~=1.18
    #   jupyter-client (>=5.3.4)
    #   ipykernel
    #   nbsphinx ; extra == 'docs'
    #   Send2Trash
    #   sphinxcontrib-github-alt ; extra == 'docs'
    #
    # We extract the first letters, digits, and dashes at the start of the line.
    return re.findall("^[\w\d-]*", requirement_line)[0]


def get_cpu_name():

    os_type = system()

    if os_type == "Linux":
        with open("/proc/cpuinfo") as f:
            lines = f.readlines()
        line = next(l for l in lines if l.startswith("model name"))
        cpu_name = line.split(": ")[1].strip()

    elif os_type == "Windows":
        from winreg import ConnectRegistry, OpenKey, QueryValueEx, HKEY_LOCAL_MACHINE

        reg = ConnectRegistry(None, HKEY_LOCAL_MACHINE)  # 'None': local pc, not remote
        key = OpenKey(reg, r"HARDWARE\DESCRIPTION\System\CentralProcessor\0")
        cpu_name, _ = QueryValueEx(key, "ProcessorNameString")
        reg.Close()

    elif os_type == "Darwin":  # MacOS
        cpu_name = get_cmd_output("sysctl -n machdep.cpu.brand_string").strip()

    else:
        cpu_name = "CPU unknown"

    return cpu_name


def get_cmd_output(cmd: str, **kwargs) -> str:
    # We don't use `check_output`, as that function raises an error on non-zero return
    # codes. `run` does not. (`pip show unitlib` returns code 120).
    kwargs.update(capture_output=True, text=True)
    completed_process = run(cmd.split(), **kwargs)
    return completed_process.stdout
