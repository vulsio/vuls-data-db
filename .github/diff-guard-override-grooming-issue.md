## diff-guard override re-triage

It is time for the periodic re-triage of the per-target diff-guard threshold overrides — the `DB_RATE_THRESHOLD_OVERRIDES` / `DETECTION_RATE_THRESHOLD_OVERRIDES` env lists in `db-nightly.yml` (and, while `db-main.yml` still runs the combined-rate guard, its `DB_CHANGE_RATE_THRESHOLD_OVERRIDES` / `DETECTION_CHANGE_RATE_THRESHOLD_OVERRIDES` lists). This issue is filed automatically on a ~2-month cadence; **close it once the re-triage is done.**

> **How to process this issue:** follow the runbook at [`.github/diff-guard-override-grooming-runbook.md`](https://github.com/vulsio/vuls-data-db/blob/main/.github/diff-guard-override-grooming-runbook.md) — it has the exact commands, the log-parsing recipe, the decision rules, and the output conventions. The policy below is the summary.

### Why this is needed

The override lists were seeded (#152, #153) from a **failure-only** triage, which is structurally *additive*: it discovers overrides but never retires them — a target whose churn has subsided simply stops failing and disappears from a failure triage. Without a periodic groom the lists grow monotonically and the guard's signal degrades.

### Policy

**Input** — all `db-main` + `db-nightly` builds over the trailing ~2 months, **pass and fail alike**. PASS builds are the essential part: they are what reveal an override is no longer needed. The diff report prints a change-rate row for every target on every run, so each overridden target's full distribution over the window is directly observable.

**Scope** — the whole override list is re-derived, not just appended to. The guard judges per (ecosystem, data source) for `diff db` and per (scan-result file, data source) for `diff detection`, on separate change axes — `added`, `changed` (db only) and `removed` — each with its own default (added 30% / db changed 10% / db removed 10% / detection removed 5%). An override entry is `<key>=<axis>:<rate>` and relaxes only the axis it names; keys may be ecosystem-/file-wide (`ubuntu:26.04=added:80`, `debian_13=added:50`) or slash-qualified to a single source (`cpe/cisco-json=removed:25`, `cpe_jvn/jvn-feed-rss=added:50` — the narrower key wins). Prefer the narrowest key and axis that cover the churn. For each existing entry, against that axis' observed distribution for the target over the window:

- max observed ≤ the axis' **default** threshold → **drop** the override;
- would pass at a value below the current one → **narrow** it to (observed peak + headroom);
- still needs the current value → **keep**.

Then an additive pass for newly-recurring FAIL (target, axis) pairs, using the same criteria as #152: an override is warranted only for recurring upstream-driven churn (new distros, recent releases, periodic vendor cycles) — not one-off spikes or a single batch stuck behind the guard. A `removed` override needs evidence that the source routinely loses that share of its detections, not just a FAIL count.

### Checklist

- [ ] Pull the trailing ~2 months of `db-main` + `db-nightly` runs (pass and fail).
- [ ] For each current override entry, tabulate the target's change-rate distribution → drop / narrow / keep.
- [ ] Additive pass over newly-recurring FAIL targets.
- [ ] Open a PR updating the override env lists in both workflows; link it here.
- [ ] Close this issue.
