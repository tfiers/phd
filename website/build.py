#!/usr/bin/env python
import sys
from shutil import copy
from subprocess import run


def run_jb_cmd(cmd):
    run(["jupyter-book", cmd, "."], stdout=sys.stdout, stderr=sys.stderr)


run_jb_cmd("clean")
run_jb_cmd("build")

# Add html file to website root to prove to Google we own this website.
copy("_static/googlea70385b87ca631e1.html", "_build/html/")
