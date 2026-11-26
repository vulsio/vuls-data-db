## Save the RHEL package manifest pages

Red Hat revises the RHEL package manifest at each minor release, in May and November, and docs.redhat.com refuses CI, so the pages that fetch-redhat-package-manifest.yml reads are saved by hand. This issue is filed automatically in June and December. **Close it once the pages are saved, or once you have checked that none changed.**

> **How to process this issue:** follow [`redhat-package-manifest/README.md`](https://github.com/vulsio/vuls-data-db/blob/main/redhat-package-manifest/README.md). It has the list of pages, how to save them, and the command that cuts them down.

### Checklist

- [ ] Check the README's list of pages against the documentation: a repository page added to or dropped from RHEL 10's Repositories page, a new major release, or a manifest that moved to other pages.
- [ ] Save each page from a browser, as HTML only.
- [ ] Run `python3 redhat-package-manifest/trim.py <saved page>...`.
- [ ] Open a PR with the pages, and link it here.
- [ ] After it is merged, check that the next fetch of vuls-data-raw-redhat-package-manifest passed.
- [ ] Close this issue.
