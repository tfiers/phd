#!/usr/bin/env python

import sys
from subprocess import run


def run_jb_cmd(cmd):
    run(["jupyter-book", cmd, "."], stdout=sys.stdout, stderr=sys.stderr)


def add_meta_tag():
    """ To prove to Google we own this website. """
    # This file only contains a bare <meta> refresh tag.
    index_html_file = "./_build/html/index.html"
    with open(index_html_file) as f:
        existing_lines = f.readlines()
    new_lines = [
        "<html><head>\n",
        '<meta name="google-site-verification" content="QPn27BqA5LpMmT7Y7mFDLlWCeUw5aVcr74ShytJ3hJU" />\n',
        *existing_lines,
        "</head></html>\n",
    ]
    with open(index_html_file, "w") as f:
        f.writelines(new_lines)


run_jb_cmd("clean")
run_jb_cmd("build")
add_meta_tag()
