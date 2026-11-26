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

You need `vuls-data-update` from main (`go install github.com/MaineK00n/vuls-data-update/cmd/vuls-data-update@main`). You also need a GitHub token that can write the packages of vulsio, in `GITHUB_TOKEN` rather than on the command line. For example, run `gh auth refresh -s write:packages` once, then `export GITHUB_TOKEN="$(gh auth token)"`.

- [ ] Save each page from a browser, with "Save Page As": "Web Page, HTML only" (Firefox) or "Webpage, HTML Only" (Chrome).
- [ ] Pull the raw repository, with its files on disk:

  ```sh
  vuls-data-update dotgit pull --restore --dir . --checkout main ghcr.io/vulsio/vuls-data-db:vuls-data-raw-redhat-package-manifest
  ```

- [ ] Delete from `origin/` any page that the list no longer has, before the next step. A page left behind by a manifest that moved holds the same tables as the new pages, and the next step refuses both.
- [ ] Store the saved pages, and read the tables again:

  ```sh
  vuls-data-update fetch redhat-package-manifest --dir ghcr.io/vulsio/vuls-data-db/vuls-data-raw-redhat-package-manifest <saved page>...
  ```

  It stores each page's `<article>` at the path of its URL. Every table is read before anything is written, so a page that is not one of the manifest, or a run that fails for any other reason, leaves the repository as it was.
- [ ] See what changed with `git status` and `git diff --stat -- package module` in the repository.
  - The tables are what tell whether the manifest changed.
  - The pages of RHEL 8 and 9 carry ids that each build of the documentation generates anew, so a rebuilt page differs even where its tables do not.
- [ ] Commit, and push the repository to the registry:

  ```sh
  git -C ghcr.io/vulsio/vuls-data-db/vuls-data-raw-redhat-package-manifest add -A
  git -C ghcr.io/vulsio/vuls-data-db/vuls-data-raw-redhat-package-manifest commit -m "save the RHEL package manifest pages"
  vuls-data-update dotgit compress ghcr.io/vulsio/vuls-data-db/vuls-data-raw-redhat-package-manifest
  vuls-data-update dotgit registry push --force ghcr.io/vulsio/vuls-data-db:vuls-data-raw-redhat-package-manifest vuls-data-raw-redhat-package-manifest.tar.zst
  ```

  Push when none of the workflows that push this tag is running. A run that pulled before your push, and then pushes, takes your commit back. The fetch job pushes only when it commits, but the Git GC that Fetch All and gc-raw.yml run always pushes. So do archive-raw.yml, truncate.yml run on this tag, and restore-all.yml.

  ```sh
  for w in fetch-all.yml fetch-redhat-package-manifest.yml gc-raw.yml archive-raw.yml truncate.yml restore-all.yml; do gh run list --repo vulsio/vuls-data-db --workflow "$w" --status in_progress; done
  ```

- [ ] After the next Fetch All, check two things: its fetch of vuls-data-raw-redhat-package-manifest passed, and the repository still holds your commit.
- [ ] Close this issue.
