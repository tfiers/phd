#!/usr/bin/env python

import sys
from subprocess import run

import yaml


def run_jb_cmd(cmd):
    run(["jupyter-book", cmd, "."], stdout=sys.stdout, stderr=sys.stderr)


def expand_subsections():
    # r+ = text file in read & write mode.
    toc_filename = "_toc.yml"
    with open(toc_filename, mode="r+") as f:
        toc = yaml.safe_load(f)
        for file in toc["sections"]:
            if "sections" in file:
                file["expand_sections"] = True
        f.seek(0)
        f.truncate()
        print(f"{toc_filename} after processing:")
        print(yaml.dump(toc))
        print("")
        yaml.dump(toc, f)


run_jb_cmd("clean")
run_jb_cmd("toc")
expand_subsections()
run_jb_cmd("build")
