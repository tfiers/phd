#!/usr/bin/env python

import sys
from pathlib import Path
from subprocess import run

from lxml import etree


def run_jb_cmd(cmd):
    run(["jupyter-book", cmd, "."], stdout=sys.stdout, stderr=sys.stderr)


META_TAG_STRS = (
    # Direct search engines to not index this page.
    '<meta name="robots" content="noindex" />',
    # Prove to Google we own this website.
    '<meta name="google-site-verification" content="QPn27BqA5LpMmT7Y7mFDLlWCeUw5aVcr74ShytJ3hJU" />',
)


def add_meta_tags_to_all_pages():
    html_file_paths = map(str, Path("./_build/html/").glob("**/*.html"))
    parser = etree.HTMLParser()
    meta_tags = [etree.fromstring(tag) for tag in META_TAG_STRS]
    for html_file_path in html_file_paths:
        try:
            tree = etree.parse(html_file_path, parser)
            head = tree.find("head")
            for meta_tag in meta_tags:
                head.append(meta_tag)
            tree.write(html_file_path, method="html")
            print(f"Added meta tags to {html_file_path}")
        except:
            print(f"Could not add meta tags to {html_file_path}")


run_jb_cmd("clean")
run_jb_cmd("build")
add_meta_tags_to_all_pages()
