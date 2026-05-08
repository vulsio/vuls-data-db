#!/usr/bin/env bash
# expand-overrides.sh — Expand a multi-line "<key>=<rate>" string (read from
# the env var named by $1) into a stream of `--change-rate-threshold-override
# <entry>` tokens, one per line, on stdout.
#
# Caller pattern (each diff-guard step):
#
#   mapfile -t overrides_args < <(
#     bash "${GITHUB_ACTION_PATH}/expand-overrides.sh" \
#       DETECTION_CHANGE_RATE_THRESHOLD_OVERRIDES
#   )
#   vuls diff detection ... "${overrides_args[@]}"
#
# Why centralize: the parsing rules (comment stripping, whitespace handling,
# blank-line skipping) used to live inline in three diff steps. Keeping them
# in one place avoids drift if those rules ever change. Value-shape
# validation (numeric, non-empty key, non-negative, finite) intentionally
# stays in vuls2's CLI parser — this script is purely a textual splitter.
#
# Usage: expand-overrides.sh <ENV_VAR_NAME>
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "expand-overrides.sh: expected exactly 1 arg (env var name), got $#" >&2
  exit 2
fi

input="${!1-}"

while IFS= read -r line; do
  # Strip trailing "# ..." comments. Note: this is a deliberate one-pass
  # strip — there's no syntax for escaping a literal "#" in entries because
  # ecosystem ids and scan-result file basenames don't contain "#".
  line="${line%%#*}"
  # Trim leading and trailing whitespace (spaces and tabs). awk's "{$1=$1};1"
  # is the standard idiom for whitespace normalization.
  line="$(printf '%s' "$line" | awk '{$1=$1};1')"
  [ -z "$line" ] && continue
  printf -- '--change-rate-threshold-override\n%s\n' "$line"
done <<< "$input"
