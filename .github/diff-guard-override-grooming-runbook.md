# diff-guard override grooming — runbook

Executable procedure for the periodic re-triage of the diff-guard per-target
threshold overrides. It is triggered by the auto-filed `diff-guard-grooming`
issue (see `.github/workflows/diff-guard-override-grooming.yml`); hand this
runbook to whoever works that issue — human or LLM. The issue body carries the
*policy* (the summary); this file is the *procedure*.

Repo: `vulsio/vuls-data-db`. The `gh` commands below omit
`--repo vulsio/vuls-data-db` for brevity — add it, or run from a clone.

## What you are grooming

Two workflows run the diff guard, each on a 6-hour cron:

- **`db-main.yml`** (workflow name `DB`) — builds from `BRANCH=main`, installs
  `vuls@main`, baseline is the previous `:<schema_version>` image.
- **`db-nightly.yml`** (workflow name `DB(Nightly)`) — builds from
  `BRANCH=nightly`, installs `vuls@nightly`, baseline is the previous
  `:nightly` image.

Each workflow's `build` job carries two override lists in its `env:` block:

- `DB_CHANGE_RATE_THRESHOLD_OVERRIDES` — `<ecosystem>=<rate>` lines, for
  `vuls diff db` (default threshold `DB_CHANGE_RATE_THRESHOLD`, 10%).
- `DETECTION_CHANGE_RATE_THRESHOLD_OVERRIDES` — `<scan-result-file>=<rate>`
  lines, for `vuls diff detection` (default `DETECTION_CHANGE_RATE_THRESHOLD`, 5%).

Goal: re-derive both lists from the last ~2 months of data so they neither go
stale (overrides for targets that have calmed down) nor miss newly-recurring
churn. The whole list is re-derived, not just appended to.

## Step 1 — Collect the run list

Window: the trailing ~2 months from today. Metadata only (cheap):

```
gh run list --workflow db-main.yml    --created '>=<YYYY-MM-DD>' --limit 400 \
  --json databaseId,conclusion,createdAt,event
gh run list --workflow db-nightly.yml --created '>=<YYYY-MM-DD>' --limit 400 \
  --json databaseId,conclusion,createdAt,event
```

You now have, per workflow, every run with its conclusion (~240 runs each).

## Step 2 — Decide which run logs to read

Do **not** fetch every run's log. You need:

- **All FAIL runs** — group consecutive failures into *events*: a streak of
  failures is usually one upstream cause re-failing because promotion is
  blocked. Read 1–2 representative logs per FAIL event.
- **PASS runs — signal-bearing only.** A PASS run inherits its DB diff from
  its inputs: if no source's extracted dotgit advanced between two consecutive
  builds, the second build sees identical anchors and the diff guard reports
  the same rates (typically near-0%) — a duplicate that does not move any
  target's distribution. Group PASS runs by their extract-anchor tuple and
  read **one log per group** (the earliest run in the group is the
  representative). Time-uniform sampling (e.g. "1 every 3 days") is a poor
  fit: override-worthy excursions are bursty and concentrated in
  immediately-after-extract runs, which uniform sampling underweights.

### How to compute the extract-anchor tuple

The enabled data sources for each pipeline are listed in `db-main.mk` /
`db-nightly.mk`. For each enabled source, pull the extracted dotgit once and
read its commit log over the window:

```
vuls-data-update dotgit pull --dir /tmp/ex \
  --restore ghcr.io/vulsio/vuls-data-db:vuls-data-extracted-<source>
git -C /tmp/ex/ghcr.io/vulsio/vuls-data-db/vuls-data-extracted-<source> \
  log --format='%H %ct' --since='<window-start>'
```

(`%ct` is committer-time as epoch — sortable across sources without timezone
fuss.) For each run with start time `T`, the tuple is the per-source latest
extracted commit at-or-before `T`. Runs with identical tuples are duplicates.

The arithmetic is small (~240 runs × O(sources) lookups), so a throwaway
script is the natural tool — write whatever shape fits the moment. If it
turns out to be reusable across grooming cycles, drop it under `.github/`
next time; pre-creating it is not required.

Fetching logs is the expensive part — fan the reads out in parallel (runs are
independent; e.g. several parallel workers/agents).

## Step 3 — Extract the change-rate rows

```
gh run view <run-id> --log
```

The diff guard is a composite action; in these workflows its sub-steps may
appear as `UNKNOWN STEP` in the log — **do not grep on the step name.** Grep on
the report-table rows instead.

The `Run diff guard` step prints a markdown report per diff. Column layouts vary
slightly by `vuls` version, so read the header row to map columns. Typical:

- **`vuls diff detection`** — `| Name | Baseline | Target | Added | Removed | Change Rate | [Threshold] | Result |`
- **`vuls diff db`** — `| Ecosystem | Detection Change Rate | KB Change Rate | [Threshold] | Result |`

For each sampled run, record per target: name, change rate(s), and Result
(PASS / FAIL). The report lists *every* target, so one sampled run yields the
full picture for that run.

## Step 4 — Per-entry decision: drop / narrow / keep

For **each entry currently in the override lists**, build the target's
change-rate distribution over the window from the sampled runs, then:

| observed over the window | action |
|---|---|
| max rate ≤ the **default** threshold (db 10% / detection 5%) | **drop** the override |
| max rate ≤ a value lower than the current override | **narrow** to `(observed peak) + headroom` |
| still needs the current value | **keep** |

- **Headroom** — roughly 1.3–2× the observed peak. Exception: a *fast-growing
  new distro* (a just-released stable still backfilling CVEs, etc.) warrants
  forward-looking headroom beyond today's peak, since its rate will keep
  climbing — re-loosening every cycle is worse than one wider band. Record the
  reasoning in the PR.
- **Stuck-batch caveat** — a target showing a *flat, identical rate across a
  run streak* is one upstream batch re-failing behind a blocked promotion;
  count it as **one event**, not N. Recurrence is judged by distinct events,
  not run count.

## Step 5 — Additive pass: new overrides

From the FAIL events, find targets *not* currently overridden that tripped the
guard. Add an override only for **recurring upstream-driven churn that is not a
regression**:

- ✅ new distro generations, recent releases, rolling releases, periodic
  vendor-data cycles — recurring across **multiple distinct events**;
- ❌ one-off spikes; a single stuck batch; EOL-distro anomalies; a brand-new
  ecosystem with an empty baseline (100% — self-resolves after one promotion).

Same criteria as #152 / #153 — see those PRs for worked FAIL tables and
include/exclude rationale.

## Step 6 — Apply

Edit the `env:` blocks in **both** `.github/workflows/db-main.yml` and
`.github/workflows/db-nightly.yml`:

- `DB_CHANGE_RATE_THRESHOLD_OVERRIDES` / `DETECTION_CHANGE_RATE_THRESHOLD_OVERRIDES`.
- One `<key>=<rate>` per line. **No `#` comments inside the lists** — vuls2's
  override parser rejects them. Per-entry rationale goes in the PR description,
  not the YAML.
- The two pipelines have independent data (different data branch, different
  `vuls` version, baseline-age effects), so their lists legitimately differ —
  but where the **same** target is overridden in both, keep the **value
  identical**: the lists are meant to converge.

## Step 7 — Ship

- Commit on a topic branch off the latest `main`; open a PR.
- Put the FAIL/PASS evidence and the per-entry drop / narrow / keep / add
  rationale in the PR description (mirror the format of #152 / #153).
- Link the PR back to the `diff-guard-grooming` issue, then **close that
  issue** — its checklist's last item.
