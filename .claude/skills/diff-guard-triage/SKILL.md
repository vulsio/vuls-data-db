---
name: diff-guard-triage
description: "Triage a failed DB workflow run on vulsio/vuls-data-db where the diff-guard step (vuls diff detection / vuls diff db) failed. Classify the cause as upstream-driven, orchestration-driven, extractor-driven, vuls2-builder-driven, or threshold-only, and cite a smoking-gun raw/extracted diff. Trigger when the user pastes a failed vuls-data-db DB run URL and asks why it failed or to investigate upstream/raw/extracted changes."
---

# Diff guard triage

## 0. Prerequisites

- `vuls` (vuls2), `vuls-data-update`, `gh`, `jq`, and `git` on PATH. Install the first two from the same refs CI uses — `@main` for **DB** (`db-main.yml`), `@nightly` for **DB(Nightly)** (`db-nightly.yml`):
  ```sh
  go install github.com/MaineK00n/vuls-data-update/cmd/vuls-data-update@main  # @nightly when triaging a DB(Nightly) run
  go install github.com/MaineK00n/vuls2/cmd/vuls@main                         # @nightly when triaging a DB(Nightly) run
  ```
- Local checkouts of vuls2 / vuls-data-update are **optional**. The steps that inspect their commit history rule out via the GitHub API first, and clone on demand only when a deep dive is needed.

## 1. Identify which DB workflow fired

The DB workflow exists in two flavors. The baseline tag differs:

| Workflow file | Baseline tag | Notes |
| --- | --- | --- |
| `.github/workflows/db-main.yml` (workflow name: **DB**) | `ghcr.io/vulsio/vuls-nightly-db:<schema_version>` (computed at build time, e.g. `:0`) | Promoted to `:latest` and `:<schema_version>` on pass |
| `.github/workflows/db-nightly.yml` (workflow name: **DB(Nightly)**) | `ghcr.io/vulsio/vuls-nightly-db:nightly` (literal) | Promoted to `:nightly` on pass |

Read the failed run's workflow name from `gh run view <run-id> --repo vulsio/vuls-data-db --json workflowName` and pick the right baseline tag. The `schema_version` comes from a `Save vuls.db schema_version` step that runs `vuls db search metadata --dbpath ./vuls.db | jq .schema_version` — re-derive it from the run's logs if you need the exact value at the time.

Both workflows use the same OCI repository: `ghcr.io/vulsio/vuls-nightly-db`. The "nightly" in the repo name is a historical artifact — `db-main.yml` also publishes to it.

## 2. Pin both anchors

**Target** (the failed candidate, untagged):
- Read the run summary's "Pushed candidate image" section, or scrape `digest=` from the `Push vuls.db to GHCR (tagless, digest-only)` step's log. `<digest>` below always means the full `sha256:<64hex>` string exactly as it appears there.
- Form the ref: `ghcr.io/vulsio/vuls-nightly-db@<digest>`.
- The image is intentionally untagged on failure — promotion to `:<schema_version>` / `:nightly` is gated on diff-guard passing.

**Baseline** (what `:<tag>` was pointing to at the moment diff-guard ran):
- Tag promotions happen via two paths, and the baseline is the digest from whichever promotion completed most recently **before the failed run's diff-guard step executed** (a tag can be moved by another run while the failed run is in progress) — check both:
  - Automatic: a **successful** DB / DB(Nightly) run's own `Promote digest to :latest and :<schema_version>` (or `:nightly`) step. The failed run's own step is **skipped**, but an earlier successful run of the same workflow may have moved the tag this way. Find it and read the promoted digest from its "Pushed candidate image" summary / promote step log:
    ```sh
    gh run list --repo vulsio/vuls-data-db --workflow db-main.yml --status success --limit 5 --json createdAt,databaseId,displayTitle
    ```
    (use `--workflow db-nightly.yml` when triaging a DB(Nightly) run)
  - Manual: the `DB(Promote Digest)` workflow (`.github/workflows/promote-digest.yml`), invoked via `workflow_dispatch`, with target tag matching the workflow (e.g., `:0` for db-main, `:nightly` for db-nightly):
    ```sh
    gh run list --repo vulsio/vuls-data-db --workflow promote-digest.yml --limit 20 --json createdAt,displayTitle,conclusion
    ```
    The `displayTitle` is `Promote :<tag> <- <digest> by @<actor>` (see `run-name` in `promote-digest.yml`).
- The most recent of the two is the baseline. Form the ref the same way: `ghcr.io/vulsio/vuls-nightly-db@<digest>`.
- Note the registry API (`gh api /orgs/vulsio/packages/container/vuls-nightly-db/versions`) only reflects **current** tag→digest associations — use it to sanity-check the present state, not to reconstruct where a tag pointed in the past. Historical baselines must come from the Actions promotion history above.

## 3. Extract anchors from each DB

```sh
mkdir -p /tmp/db-investigation && cd /tmp/db-investigation
vuls db fetch --dbpath ./baseline.db --repository <baseline ref> --no-progress
vuls db fetch --dbpath ./target.db   --repository <target   ref> --no-progress

# Builder version (vuls2). If different between b and t, builder is in scope.
vuls db search metadata --dbpath ./baseline.db | jq '{schema_version, last_modified, created_by}'
vuls db search metadata --dbpath ./target.db   | jq '{schema_version, last_modified, created_by}'

# Per-source raw and extracted commits.
vuls db search datasources --dbpath ./baseline.db | jq '.[] | select(.id=="<source>")'
vuls db search datasources --dbpath ./target.db   | jq '.[] | select(.id=="<source>")'
```

The `<source>` is the datasource id from `db-main.mk` / `db-nightly.mk` — e.g. `ubuntu-cve-tracker`, `redhat-vex`, `debian-security-tracker-salsa`.

For ubuntu specifically, only one source is enabled (`ubuntu-cve-tracker`). For other OS families, multiple sources may need to be checked.

## 4. Diff in the right order (rule out builder → extractor → orchestration → upstream)

### a. vuls2 builder

Compare `created_by` strings. If identical, builder is ruled out. If they differ, list vuls2's commits in the date range between the two strings' embedded timestamps before drawing conclusions:

```sh
gh api --paginate "repos/MaineK00n/vuls2/commits?per_page=100&since=<baseline_ts>&until=<target_ts>" \
  --jq '.[] | .sha[0:7] + " " + .commit.committer.date + " " + (.commit.message | split("\n")[0])'
```

### b. vuls-data-update extractor

The extractor binary that produced the extracted dotgit isn't recorded in the DB metadata. Approximate: look for commits touching `pkg/extract/<source>/` and `pkg/fetch/<source>/`, scoped to the date range between the two extracted commits' timestamps (from step 3).

**Rule-out first** — no checkout needed:

```sh
for p in pkg/extract/<source> pkg/fetch/<source>; do
  gh api --paginate "repos/MaineK00n/vuls-data-update/commits?per_page=100&path=$p&since=<baseline_ext_date>&until=<target_ext_date>" \
    --jq '.[] | .sha[0:7] + " " + .commit.committer.date + " " + (.commit.message | split("\n")[0])'
done
```

No commits → extractor is ruled out; move on to c. Commits found → they are candidates, and need a deep dive: the commits API truncates large patches and can't grep the tree, so use a real checkout. Prefer an existing local clone if the user has one; otherwise blobless-clone on demand:

```sh
[ -d /tmp/db-investigation/vuls-data-update ] || \
  git clone --filter=blob:none https://github.com/MaineK00n/vuls-data-update /tmp/db-investigation/vuls-data-update
git -C /tmp/db-investigation/vuls-data-update log -p \
  --since=<baseline_ext_date> --until=<target_ext_date> -- pkg/extract/<source> pkg/fetch/<source>
```

Read each candidate commit's diff and the surrounding extraction logic (the current `pkg/extract/<source>/` tree) before drawing conclusions — a commit touching the path is a candidate, not a verdict.

### c. extracted dotgit

```sh
vuls-data-update dotgit pull --dir /tmp/ex --checkout <main|nightly> --restore ghcr.io/vulsio/vuls-data-db:vuls-data-extracted-<source>
EX=/tmp/ex/ghcr.io/vulsio/vuls-data-db/vuls-data-extracted-<source>
git -C "$EX" log --format='%h %ci' <baseline_ext>..<target_ext>
git -C "$EX" diff --shortstat <baseline_ext>..<target_ext>
```

`--checkout` must match the triaged workflow's branch — `main` for **DB**, `nightly` for **DB(Nightly)** (its build runs `make -f db-nightly.mk ... BRANCH=nightly`). The default is `main`, and the anchor commits from step 3 may only exist on the matching branch. The same applies to the raw dotgit pull below.

The range may span multiple commits. If it does, examine **each step**, not just the cumulative diff — different commits often represent different upstream activities (schema expansion vs. bulk triage, etc.).

### d. raw dotgit

```sh
vuls-data-update dotgit pull --dir /tmp/raw --checkout <main|nightly> --restore ghcr.io/vulsio/vuls-data-db:vuls-data-raw-<source>
RAW=/tmp/raw/ghcr.io/vulsio/vuls-data-db/vuls-data-raw-<source>
git -C "$RAW" log --format='%h %ci' <baseline_raw>..<target_raw>
git -C "$RAW" diff --shortstat <baseline_raw>..<target_raw>
```

If raw is unchanged but extracted moved → extractor is the source. If raw also changed → check e before concluding "upstream": the raw repo records what the fetch *config* asked for, and that config lives in vuls-data-db itself.

### e. vuls-data-db fetch orchestration

Raw movement is only "upstream" if nobody changed what we fetch. Fetch scope lives in vuls-data-db (`.github/workflows/*-targets.json` seed lists — e.g. `msuc-targets.json` — and the fetch workflow files). Check for merged changes in the **raw** anchor window:

```sh
gh api --paginate "repos/vulsio/vuls-data-db/commits?per_page=100&path=.github/workflows&since=<baseline_raw_date>&until=<target_raw_date>" \
  --jq '.[] | .sha[0:7] + " " + .commit.committer.date + " " + (.commit.message | split("\n")[0])'
```

Hits touching seed/target files are candidates. Verify by intersecting the seeds a PR added with the IDs added in the raw/extracted diff (IDs from `git diff --diff-filter=A --name-only <baseline>..<target>` vs `gh pr diff <n>` — `comm -12` on the sorted lists). A high overlap is the verdict.

## 5. Classify and cite

Output the verdict as one of:

- **upstream-driven** — raw moved, no vuls-data-update extractor/fetch code changes in the window (step 4b), no fetch-orchestration changes in vuls-data-db (step 4e), builder unchanged. Show the smoking-gun raw status flip (e.g., `needs-triage → needed`) on a representative file. Usually legitimate; consider per-target threshold override (see below).
- **orchestration-driven** — raw moved because vuls-data-db changed what gets fetched (step 4e: seed/target registration, fetch workflow scope). Cite the vuls-data-db PR(s) and the seed↔added-ID overlap count. Usually an intentional one-time expansion: promote after inspection rather than adjusting thresholds.
- **extractor-driven** — raw unchanged but extracted moved. Show a same-file diff between `<baseline_ext>` and `<target_ext>` and link to the offending commit in `pkg/extract/<source>/`.
- **vuls2-builder-driven** — anchors unchanged but `created_by` differs. Link to the vuls2 commit in the date range.
- **threshold-only** — small baseline (e.g. `ubuntu_2604` with baseline ~200 detections) tripping the global threshold on routine noise. Recommend a per-file or per-ecosystem override:
  - Detection: `detection_change_rate_threshold_overrides` in the workflow's `with:` block (entries like `ubuntu_2604=20`).
  - DB: `db_change_rate_threshold_overrides` (entries like `ubuntu:26.04=15`).

Always cite at least one concrete CVE file diff (raw or extracted) as evidence — never just summarize "looks upstream".

**Write the final triage report to the user in Japanese** (日本語), regardless of the language used during investigation. Keep identifiers verbatim — commit hashes, digests, CVE IDs, tags, file paths, workflow/source names, and metric tables stay as-is; only the prose (verdict, reasoning, recommendations) is in Japanese.

## 6. Don't do this

- **NEVER run `gh workflow run` against this repo (vulsio/vuls-data-db) — under any circumstances.** This includes `promote-digest.yml`. `workflow_dispatch` here moves production tags (`:0` / `:latest` / `:nightly`) and cannot be undone. If triage concludes a candidate should be promoted, **present the exact command and stop** — a human runs it. This holds even if the user says "go ahead": your role ends at showing the command. Read-only `gh` (`gh run view` / `gh run list` / `gh api ...`) is fine.
- **Don't** diff `HEAD vs HEAD~1` of the dotgit and call it the answer. The two anchors may span multiple commits, and you'll miss the earlier ones.
- **Don't** treat `:0` / `:latest` / `:nightly` at *now* as the baseline. The baseline is what those tags pointed to **when the failed run executed**. Use the promote-digest history.
- **Don't** assume `KB Change Rate = 0%` means "nothing changed". The metric measures one specific aspect of the bolt buckets and can show 0% even when many CVE entries had their `Vulnerable` flag flipped. Cross-check with raw status histograms (`grep -E '"status":' | sort | uniq -c`).
- **Don't** auto-commit conclusions to memory. Each diff-guard failure has its own root cause; the procedure here is what should be remembered, not the verdict.
