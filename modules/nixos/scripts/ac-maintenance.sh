#!/usr/bin/env bash
# Called by systemd ExecCondition and ExecStopPost. Paths are supplied by Nix.
set -euo pipefail

action=$1
marker=$2
case "$action" in
  check)
    # Record work BEFORE checking power, so a skipped calendar event survives
    # both logout and reboot. StateDirectory creates the root-owned parent.
    touch "$marker" || exit 255
    if "$3"; then
      exit 0
    else
      status=$?
      if [[ $status == 1 ]]; then
        echo "Deferring maintenance until AC power is available."
        exit 1 # ExecCondition: skip without marking the service failed.
      fi
      echo "Cannot determine AC power state; retaining pending maintenance." >&2
      exit 255
    fi
    ;;
  finish)
    # A skipped condition, failed job, timeout or interrupted scrub must remain
    # pending. Only the main process's successful completion clears the marker.
    if [[ ${SERVICE_RESULT:-} == success && ${EXIT_CODE:-} == exited && ${EXIT_STATUS:-} == 0 ]]; then
      rm -f -- "$marker"
    fi
    ;;
  *)
    echo "Unknown maintenance action: $action" >&2
    exit 2
    ;;
esac
