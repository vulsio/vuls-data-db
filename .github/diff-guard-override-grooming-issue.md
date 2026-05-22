## diff-guard override re-triage

It is time for the periodic re-triage of the per-target diff-guard threshold overrides — the `DB_CHANGE_RATE_THRESHOLD_OVERRIDES` / `DETECTION_CHANGE_RATE_THRESHOLD_OVERRIDES` env lists in `db-main.yml` and `db-nightly.yml`. This issue is filed automatically on a ~2-month cadence; **close it once the re-triage is done.**

> **How to process this issue:** follow the runbook at [`.github/diff-guard-override-grooming-runbook.md`](.github/diff-guard-override-grooming-runbook.md) — it has the exact commands, the log-parsing recipe, the decision rules, and the output conventions. The policy below is the summary.

### Why this is needed

The override lists were seeded (#152, #153) from a **failure-only** triage, which is structurally *additive*: it discovers overrides but never retires them — a target whose churn has subsided simply stops failing and disappears from a failure triage. Without a periodic groom the lists grow monotonically and the guard's signal degrades.

### Policy

**Input** — all `db-main` + `db-nightly` builds over the trailing ~2 months, **pass and fail alike**. PASS builds are the essential part: they are what reveal an override is no longer needed. The diff report prints a change-rate row for every target on every run, so each overridden target's full distribution over the window is directly observable.

**Scope** — the whole override list is re-derived, not just appended to. For each existing entry, against the target's observed distribution over the window:

- max observed ≤ the **default** threshold (db 10% / detection 5%) → **drop** the override;
- would pass at a value below the current one → **narrow** it to (observed peak + headroom);
- still needs the current value → **keep**.

Then an additive pass for newly-recurring FAIL targets, using the same criteria as #152: an override is warranted only for recurring upstream-driven churn (new distros, recent releases, periodic vendor cycles) — not one-off spikes or a single batch stuck behind the guard.

### Checklist

- [ ] Pull the trailing ~2 months of `db-main` + `db-nightly` runs (pass and fail).
- [ ] For each current override entry, tabulate the target's change-rate distribution → drop / narrow / keep.
- [ ] Additive pass over newly-recurring FAIL targets.
- [ ] Open a PR updating the override env lists in both workflows; link it here.
- [ ] Close this issue.
