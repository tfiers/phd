#!/usr/bin/env python
import shutil
import sys
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from subprocess import run

from lxml import etree


def copy_down_notebooks_dir():
    # I like my `nb/` dir to be top level (next to `pkg/` and `web/`).
    # But JupyterBook / Sphinx then can't find it. Hence copy it down to the website/
    # dir on build.
    try:
        shutil.copytree("../nb", "nb", dirs_exist_ok=True)
    except shutil.Error:
        pass
        # A "permission denied" error is raised on my machine, but the operation
        # succeeds succesfully anyway. So we ignore this error.


def run_jupyterbook_cmd(cmd):
    run(["jupyter-book", cmd, "."], stdout=sys.stdout, stderr=sys.stderr)


google_meta_tags = (
    # Direct search engines to not index this page.
    '<meta name="robots" content="noindex" />',
    # Prove to Google we own this website.
    '<meta name="google-site-verification" content="QPn27BqA5LpMmT7Y7mFDLlWCeUw5aVcr74ShytJ3hJU" />',
)

built_html_dir = Path("./_build/html/")


def add_google_meta_tags_to_all_pages():
    for path in built_html_dir.glob("**/*.html"):
        with edit_html(path) as tree:
            for tag in google_meta_tags:
                add_to_head(tag, tree)


@dataclass
class RenamedPage:
    old_path: str
    new_path: str


renamed_pages = (
    RenamedPage(
        "nb/2021_01_01__vary_params.html",
        "nb/2021-01-01__vary_params.html",
    ),
    RenamedPage(
        "nb/2020_12_30__test_all_connections.html",
        "nb/2020-12-30__test_all_connections.html",
    ),
)

website_url = "https://tfiers.github.io/phd/"


def add_link_tag_to_renamed_pages():  # to retain Hypothesis annotations
    for page in renamed_pages:
        with edit_html(built_html_dir / page.new_path) as tree:
            existing_link_tag = tree.find('//link[@rel="canonical"]')
            existing_link_tag.getparent().remove(existing_link_tag)
            add_to_head(
                f'<link rel="canonical" href="{website_url + page.old_path}" />',
                tree,
            )


parser = etree.HTMLParser()


@contextmanager
def edit_html(file_path) -> etree.ElementTree:
    file_path_str = str(file_path)
    tree = etree.parse(file_path_str, parser)
    try:
        yield tree
    except Exception as e:
        print(f"Error editing {file_path}:", e)
    finally:
        tree.write(file_path_str, method="html")
        print(f"Wrote to {file_path}")


def add_to_head(tag, tree):
    head = tree.find("head")
    head.append(etree.fromstring(tag))


if __name__ == "__main__":
    copy_down_notebooks_dir()
    run_jupyterbook_cmd("clean")
    run_jupyterbook_cmd("build")
    add_google_meta_tags_to_all_pages()
    add_link_tag_to_renamed_pages()
