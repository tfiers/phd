#!/usr/bin/env python

import sys
from subprocess import run


def run_jb_cmd(cmd):
    run(["jupyter-book", cmd, "."], stdout=sys.stdout, stderr=sys.stderr)


run_jb_cmd("clean")
run_jb_cmd("build")


