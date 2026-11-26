#!/usr/bin/env python3
"""Cut pages saved from docs.redhat.com down to their <article>, and put each
where `vuls-data-update fetch redhat-package-manifest` reads it.

Usage: python3 redhat-package-manifest/trim.py <saved page>...

The <article> element is the text of the document, which Red Hat licenses
under CC BY-SA 3.0, and holds every table; the rest of the page is the site
around it. It is written byte for byte, to the path of the page's URL under
https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/ with
".html" added, beside this script: the page's canonical link names the URL.

  .../red_hat_enterprise_linux/9/html-single/package_manifest/index
      -> 9/html-single/package_manifest/index.html
  .../red_hat_enterprise_linux/10/plan-baseos -> 10/plan-baseos.html

A page is refused, and nothing is written for it, unless it has a canonical
link under that URL, exactly one <article>, and a table in it.
"""

import os
import re
import sys
from urllib.parse import urlsplit

PREFIX = "/en/documentation/red_hat_enterprise_linux/"
# What follows PREFIX: a major release, then the page.
PAGE = re.compile(r"[0-9]+(/[A-Za-z0-9_-]+)+")

CANONICAL = re.compile(rb"<link\b[^>]*\brel=\"canonical\"[^>]*>")
HREF = re.compile(rb"\bhref=\"([^\"]*)\"")
ARTICLE_START = re.compile(rb"<article[\s>]")
ARTICLE_END = re.compile(rb"</article>")
TABLE = re.compile(rb"<table[\s>]")


def trim(src):
    """Return the path to write the article of the page at src to, relative
    to this directory, and the article."""
    with open(src, "rb") as f:
        page = f.read()

    links = CANONICAL.findall(page)
    if len(links) != 1:
        raise ValueError(f"expected one canonical link, found {len(links)}")
    href = HREF.search(links[0])
    if href is None:
        raise ValueError("canonical link without an href")
    # RHEL 10's pages name localhost as the host of their canonical link, so
    # only the path is read.
    path = urlsplit(href.group(1).decode("ascii")).path
    if not path.startswith(PREFIX) or not PAGE.fullmatch(path[len(PREFIX):]):
        raise ValueError(f"unexpected canonical link: {href.group(1).decode('ascii')}")

    starts, ends = ARTICLE_START.findall(page), ARTICLE_END.findall(page)
    if len(starts) != 1 or len(ends) != 1:
        raise ValueError(f"expected one <article>, found {len(starts)} start and {len(ends)} end tags")
    article = page[ARTICLE_START.search(page).start():ARTICLE_END.search(page).end()]
    if not TABLE.search(article):
        raise ValueError("no table in the <article>")

    return path[len(PREFIX):] + ".html", article + b"\n"


def main(srcs):
    if not srcs:
        sys.exit(__doc__)

    root = os.path.dirname(os.path.abspath(__file__))
    failed = False
    for src in srcs:
        try:
            rel, article = trim(src)
        except (OSError, ValueError) as e:
            print(f"{src}: {e}", file=sys.stderr)
            failed = True
            continue

        dst = os.path.join(root, *rel.split("/"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(article)
        print(f"{src} -> {rel}")

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
