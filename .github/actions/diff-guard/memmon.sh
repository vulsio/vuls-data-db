#!/bin/bash
# Memory-telemetry sidecar for the heavy diff steps in the diff-guard
# action. Streams to stdout: one cheap sample line every 3s, a
# per-process breakdown every 15s, and kernel ring-buffer lines
# ([oom-watch], OOM-killer evidence) as they appear.
#
# Why stdout and not a file/artifact: the runs this exists for are the
# ones the hosted runner kills mid-step (SIGTERM/exit 143, run shown as
# "cancelled"); on such a kill every later step is skipped, so an
# upload-artifact step would never run. Lines already streamed to the
# step log survive, and the runner timestamps each one.
#
# Why the cheap sample forks nothing: when memory is nearly exhausted,
# fork/exec of external tools (`free`, `ps`) is exactly what starts
# failing, which would silence the monitor at the moment of interest.
# The 3s line uses bash builtins reading /proc only; the fork-heavy
# per-process breakdown runs at a slower cadence and may drop out under
# pressure without losing the primary signal.
#
# Reading the output:
#   - avail/swapfree are instantaneous, 3s resolution.
#   - pgmajfault/pswpout are cumulative kernel counters: deltas between
#     consecutive lines expose thrashing that happened between samples,
#     so nothing is lost to the sampling interval.
#   - psi(some) is /proc/pressure/memory: avg10 integrates the last 10s
#     of memory stall time, surviving spikes shorter than the interval.
#   - Per-process rss overcounts shared pages (each worker maps the
#     same multi-GiB bolt DB); anon (RssAnon) is the unreclaimable heap
#     and is the number that actually crowds the VM.
set -u

cleanup() {
  trap - TERM INT EXIT
  # The dmesg watcher is root-owned (sudo), so a plain kill would get
  # EPERM; route its kill through sudo. Its sed prefixer then exits on
  # EOF by itself. Guard against PID reuse (the watcher may have exited
  # early, e.g. unsupported dmesg option): only kill if the PID is
  # still a child of this script whose comm is sudo/dmesg.
  # /proc/<pid>/stat reads "pid (comm) state ppid ..."; comm for
  # sudo/dmesg contains no spaces, so a whitespace read is safe here.
  if [ -n "${dmesg_pid:-}" ] && [ -r "/proc/${dmesg_pid}/stat" ]; then
    read -r _ watcher_comm _ watcher_ppid _ <"/proc/${dmesg_pid}/stat" || watcher_ppid=""
    if [ "$watcher_ppid" = "$$" ]; then
      case "$watcher_comm" in
        "(sudo)" | "(dmesg)") sudo -n kill "$dmesg_pid" 2>/dev/null ;;
      esac
    fi
  fi
  jobs -p | xargs -r kill 2>/dev/null
  exit 0
}
trap cleanup TERM INT EXIT

# Kernel OOM-killer evidence must already be streaming when the step
# dies — there is no later opportunity to run `dmesg` after a cancel.
# --follow-new, not --follow: only new messages, not the whole boot
# ring buffer. Process substitution rather than a pipeline so $! is
# the sudo/dmesg process itself (the one needing the sudo kill above).
dmesg_pid=""
if sudo -n true 2>/dev/null; then
  # shellcheck disable=SC2024 # the step log (our stdout) is the intended sink
  sudo -n dmesg --follow-new 2>/dev/null > >(sed -u 's/^/[oom-watch] /') &
  dmesg_pid=$!
fi

# Builtin-only sleep: `read -t` on a FIFO opened read-write never sees
# data, so it just times out — no per-iteration fork (see header note).
# The FIFO lives in a fresh mktemp -d directory (created atomically,
# mode 0700) rather than at a mktemp -u name, so no other process can
# race the path; it is unlinked as soon as fd 9 holds it open.
fifo_dir=$(mktemp -d)
mkfifo "$fifo_dir/tick"
exec 9<>"$fifo_dir/tick"
rm -rf "$fifo_dir"

i=0
while :; do
  avail=0 swapfree=0
  while read -r key value _; do
    case "$key" in
      MemAvailable:) avail=$((value / 1024)) ;;
      SwapFree:) swapfree=$((value / 1024)) ;;
    esac
  done </proc/meminfo

  pgmajfault=0 pswpout=0
  while read -r key value; do
    case "$key" in
      pgmajfault) pgmajfault=$value ;;
      pswpout) pswpout=$value ;;
    esac
  done </proc/vmstat

  psi=""
  if [ -r /proc/pressure/memory ]; then
    read -r _ psi _ </proc/pressure/memory
  fi

  echo "[memmon] avail=${avail}MiB swapfree=${swapfree}MiB${psi:+ psi(some) ${psi}} pgmajfault=${pgmajfault} pswpout=${pswpout}"

  # Fork-heavy per-process breakdown, every 5th sample. Covers the
  # diff driver (vuls) and both detection worker binaries.
  if ((i % 5 == 0)); then
    ps -C vuls,vuls0,vuls0-old -o pid=,comm=,etimes=,rss= 2>/dev/null |
      while read -r pid comm etimes rss; do
        anon=$(awk '/^RssAnon:/ {print int($2 / 1024)}' "/proc/${pid}/status" 2>/dev/null)
        echo "[memmon]   ${comm} pid=${pid} up=${etimes}s rss=$((rss / 1024))MiB anon=${anon:-?}MiB"
      done
  fi

  i=$((i + 1))
  read -r -t 3 -u 9 _ || :
done
