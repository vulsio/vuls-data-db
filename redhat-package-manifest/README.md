# Red Hat package manifest pages

The pages of the RHEL package manifest that [fetch-redhat-package-manifest.yml](../.github/workflows/fetch-redhat-package-manifest.yml) hands to `vuls-data-update fetch redhat-package-manifest`. They are saved from docs.redhat.com by hand: the site answers 403 to CI ([keycloak/keycloak#54762](https://github.com/keycloak/keycloak/issues/54762)) and to any client it does not take for a browser, and its robots.txt disallows the single-page manifests.

Each page is kept in [pages/](pages) at the path of its URL under `https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/`, with `.html` added, and cut down to its `<article>` element: the text of the document, which holds every table. The site around it is left out. `vuls-data-update` fails on anything else in pages/, as a page it would not read.

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

## Saving the pages again

Red Hat revises the manifest at each minor release, in May and November. [redhat-package-manifest-reminder.yml](../.github/workflows/redhat-package-manifest-reminder.yml) files an issue in June and December as a reminder.

1. Check the list above against the documentation.
   - RHEL 10 has a page for each repository, and [its Repositories page](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/plan-repositories) lists them. Add a page it lists that is not here, and delete the file of a page it no longer lists.
   - A new major release gets a directory of its own. Nothing else needs to change.
   - A release whose manifest moves to other pages has its old file deleted. `vuls-data-update` fails when two pages hold the same table.
2. Open each page in a browser, and save it with "Save Page As" as "Web Page, HTML only" (Firefox) or "Webpage, HTML Only" (Chrome).
3. From the root of this repository, run:

   ```sh
   python3 redhat-package-manifest/trim.py <saved page>...
   ```

   It writes the `<article>` of each page to the path of the page's canonical link in pages/. It refuses a page with no table in it, and writes nothing for that page.
4. Optionally, read them as CI will, with `vuls-data-update` built from main:

   ```sh
   vuls-data-update fetch redhat-package-manifest --dir "$(mktemp -d)" redhat-package-manifest/pages
   ```

5. Open a PR with the pages, and update the list above if it changed. Once the PR is merged, the next Fetch All commits the new tables to vuls-data-raw-redhat-package-manifest. To commit them sooner, run fetch-redhat-package-manifest.yml by hand.

## Copyright and License notice

The pages are by Red Hat, Inc.:

Copyright © 2025 Red Hat, Inc.
The text of and illustrations in this document are licensed by Red Hat under a Creative Commons Attribution–Share Alike 3.0 Unported license ("CC-BY-SA"). An explanation of CC-BY-SA is available at http://creativecommons.org/licenses/by-sa/3.0/. In accordance with CC-BY-SA, if you distribute this document or an adaptation of it, you must provide the URL for the original version.
Red Hat, as the licensor of this document, waives the right to enforce, and agrees not to assert, Section 4d of CC-BY-SA to the fullest extent permitted by applicable law.
