## Save the RHEL package manifest pages

Red Hat revises the RHEL package manifest at each minor release, in May and November. docs.redhat.com refuses CI, so the pages the tables are read from are saved by hand, and kept in `origin/` of the raw repository `vuls-data-raw-redhat-package-manifest`. This issue is filed automatically in June and December. **Close it once the pages are saved again, or once you have checked that none changed.**

### The pages

Check this list against the documentation first.
- RHEL 10 has a page for each repository, and [its Repositories page](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/plan-repositories) lists them.
- A new major release adds pages of its own.
- A release whose manifest moves to other pages leaves its old page to be deleted from `origin/`.

| Release | Page |
|---|---|
| RHEL 8 | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html-single/package_manifest/index |
| RHEL 9 | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html-single/package_manifest/index |
| RHEL 10 | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/plan-baseos |
| | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/plan-appstream |
| | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/plan-crb |
| | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/plan-supplementary |
| | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/plan-extensions |
| | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/plan-high_availability |

### Checklist

You need `vuls-data-update` from main (`go install github.com/MaineK00n/vuls-data-update/cmd/vuls-data-update@main`), and a token that can write the packages of vulsio.

- [ ] Save each page from a browser, with "Save Page As": "Web Page, HTML only" (Firefox) or "Webpage, HTML Only" (Chrome).
- [ ] Pull the raw repository and put its pages back on disk:

  ```sh
  vuls-data-update dotgit pull --dir . --checkout main ghcr.io/vulsio/vuls-data-db:vuls-data-raw-redhat-package-manifest
  git -C ghcr.io/vulsio/vuls-data-db/vuls-data-raw-redhat-package-manifest restore -- origin/
  ```

- [ ] Store the saved pages, and read the tables again:

  ```sh
  vuls-data-update fetch redhat-package-manifest --dir ghcr.io/vulsio/vuls-data-db/vuls-data-raw-redhat-package-manifest <saved page>...
  ```

  It stores each page's `<article>` at the path of its URL. It refuses a page that is not one of the manifest, and then stores nothing.
- [ ] Delete from `origin/` any page that the list no longer has.
- [ ] See what changed with `git status` and `git diff --stat -- package module` in the repository.
  - The tables are what tell whether the manifest changed.
  - The pages of RHEL 8 and 9 carry ids that each build of the documentation generates anew, so a rebuilt page differs even where its tables do not.
- [ ] Commit, and push the repository to the registry:

  ```sh
  git -C ghcr.io/vulsio/vuls-data-db/vuls-data-raw-redhat-package-manifest add -A
  git -C ghcr.io/vulsio/vuls-data-db/vuls-data-raw-redhat-package-manifest commit -m "save the RHEL package manifest pages"
  vuls-data-update dotgit compress ghcr.io/vulsio/vuls-data-db/vuls-data-raw-redhat-package-manifest
  vuls-data-update dotgit registry push --force --token <token> ghcr.io/vulsio/vuls-data-db:vuls-data-raw-redhat-package-manifest vuls-data-raw-redhat-package-manifest.tar.zst
  ```

  Push when no Fetch All is running (`gh run list --repo vulsio/vuls-data-db --workflow fetch-all.yml --status in_progress`). A run that pulled before your push would push over it.
- [ ] After the next Fetch All, check that its fetch of vuls-data-raw-redhat-package-manifest passed, and that the repository still holds your commit.
- [ ] Close this issue.
