#!/usr/bin/env python

import sys
from subprocess import run

from lxml import etree


def run_jb_cmd(cmd):
    run(["jupyter-book", cmd, "."], stdout=sys.stdout, stderr=sys.stderr)


def add_meta_tag():
    """ To prove to Google we own this website. """
    home_page_path = "./_build/html/md/home.html"
    meta_tag_str = '<meta name="google-site-verification" content="QPn27BqA5LpMmT7Y7mFDLlWCeUw5aVcr74ShytJ3hJU" />'
    parser = etree.HTMLParser()
    tree = etree.parse(home_page_path, parser)
    tree.find("head").append(etree.fromstring(meta_tag_str))
    tree.write(home_page_path, method="html")
    print(f"Added meta tag to {home_page_path}")


run_jb_cmd("clean")
run_jb_cmd("build")
try:
    add_meta_tag()
except Exception as e:
    print(e)
