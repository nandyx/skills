#!/bin/bash
# Runs a command under a wall-clock ceiling so a stuck tool never hangs an
# audit. Uses coreutils `timeout` when present, `gtimeout` on Homebrew macOS,
# and a perl alarm otherwise. Exit 124 on timeout, like coreutils.
#   with-timeout.sh <seconds> <command> [args…]
set -u
secs="${1:?usage: with-timeout.sh <seconds> <command…>}"; shift
if command -v timeout >/dev/null 2>&1; then exec timeout "$secs" "$@"; fi
if command -v gtimeout >/dev/null 2>&1; then exec gtimeout "$secs" "$@"; fi
exec perl -e '
  my $s = shift; my $pid = fork;
  if ($pid == 0) { exec @ARGV or exit 127 }
  $SIG{ALRM} = sub { kill "TERM", $pid; waitpid $pid, 0; exit 124 };
  alarm $s; waitpid $pid, 0; exit($? >> 8)' "$secs" "$@"
