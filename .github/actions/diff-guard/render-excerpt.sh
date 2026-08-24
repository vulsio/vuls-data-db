#!/usr/bin/env bash
# Render the job-summary block for one vuls diff report. Shared by the
# three diff steps in action.yml (master-HEAD detection, older-binary
# detection, `vuls diff db`) via "$GITHUB_ACTION_PATH".
#
# Usage: render-excerpt.sh <report.md> <head_n>
#
# Output: a short visible excerpt — the report's overall `**Result**`
# line plus the FAIL rows of its `## Summary` table — followed by the
# full report (first <head_n> lines) collapsed into <details>. A
# missing/empty report renders a placeholder line instead.
#
# The excerpt relies on the vuls2 report format (see "Step-summary
# layout strategy" in action.yml): `**Result**` is emitted inside
# `## Summary` by the report template (vuls2 pkg/diff/{detection,db}/
# report.go), Summary rows are sorted FAIL-first, and only FAIL rows
# carry the literal `**FAIL**` marker in the Result column. The DB
# report's `## Detection` / `## KB` tables share the Summary table's
# shape, so exiting at the first `## ` heading after `## Summary` is
# what keeps them out. The table header is only emitted when at least
# one FAIL row exists, so an all-PASS report excerpts to just its
# Result line.
set -euo pipefail

report="$1"
head_n="$2"

if [ ! -s "$report" ]; then
  echo "_(no report content — diff exited before producing output)_"
  exit 0
fi

awk '
  /^## Summary$/ { s = 1; next }
  /^## /         { if (s) exit; next }
  !s             { next }
  /^\*\*Result\*\*/ { print; print ""; next }
  /^\|/ {
    if (h < 2) { hdr[h++] = $0 }
    else if (/\*\*FAIL\*\*/) { if (!p) { print hdr[0]; print hdr[1]; p = 1 }; print }
  }
' "$report"
echo ""
echo "<details><summary>Full report (first ${head_n} lines)</summary>"
echo ""
head -n "$head_n" "$report"
echo ""
echo "</details>"
