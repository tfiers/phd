#!/usr/bin/env python

import sys
from subprocess import run

import yaml


def run_jb_cmd(cmd):
    run(["jupyter-book", cmd, "."], stdout=sys.stdout, stderr=sys.stderr)


def expand_toc_subsections():
    toc_file = "_toc.yml"
    with open(toc_file) as f:
        toc_string_in = f.read()
    print(f"Generated TOC:\n\n{toc_string_in}\n", flush=True)
    toc_dict = yaml.safe_load(toc_string_in)
    for file_dict in toc_dict["sections"]:
        if "sections" in file_dict:
            file_dict["expand_sections"] = True
    toc_string_out = yaml.dump(toc_dict)
    print(f"TOC after processing:\n\n{toc_string_out}\n", flush=True)
    with open(toc_file, "w") as f:
        f.write(toc_string_out)


run_jb_cmd("clean")
run_jb_cmd("toc")
expand_toc_subsections()
run_jb_cmd("build")
