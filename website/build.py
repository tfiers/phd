#!/usr/bin/env python
import shutil
import sys
from pathlib import Path
from subprocess import run

from lxml import etree


def copy_down_notebooks_dir():
    # I like my `notebooks/` dir to be top level (next to `codebase/` and `website/`).
    # But JupyterBook / Sphinx then can't find it. Hence copy it down to the website/
    # dir on build.
    try:
        shutil.copytree("../notebooks", "notebooks", dirs_exist_ok=True)
    except shutil.Error:
        pass
        # A "permission denied" error is raised on my machine, but the operation
        # succeeds succesfully anyway. So we ignore this error.

def run_jupyterbook_cmd(cmd):
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


copy_down_notebooks_dir()
run_jupyterbook_cmd("clean")
run_jupyterbook_cmd("build")
add_meta_tags_to_all_pages()
