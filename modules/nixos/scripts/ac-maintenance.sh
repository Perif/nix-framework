#!/usr/bin/env bash
# Called by systemd ExecCondition, ExecStopPost and the AC retry timer. Paths
# are supplied by Nix. The marker records why work is still pending:
#   pending      started on AC and has not finished
#   deferred     the calendar run was skipped on battery; retried on AC
#   interrupted  killed or timed out; retried on AC
#   failed       ran and exited non-zero; waits for the next calendar run
set -euo pipefail

action=$1
marker=$2
case "$action" in
  check)
    # Record work BEFORE checking power, so a skipped calendar event survives
    # both logout and reboot. StateDirectory creates the root-owned parent.
    printf 'pending\n' > "$marker" || exit 255
    if "$3"; then
      exit 0
    else
      status=$?
      if [[ $status == 1 ]]; then
        printf 'deferred\n' > "$marker"
        echo "Deferring maintenance until AC power is available."
        exit 1 # ExecCondition: skip without marking the service failed.
      fi
      echo "Cannot determine AC power state; retaining pending maintenance." >&2
      exit 255
    fi
    ;;
  finish)
    # Only the main process's successful completion clears the marker.
    case "${SERVICE_RESULT:-}" in
      success)
        if [[ ${EXIT_CODE:-} == exited && ${EXIT_STATUS:-} == 0 ]]; then
          rm -f -- "$marker"
        else
          printf 'interrupted\n' > "$marker"
        fi
        ;;
      exec-condition | '') ;; # Skipped on battery, or no result: keep the recorded reason.
      exit-code) printf 'failed\n' > "$marker" ;;
      *) printf 'interrupted\n' > "$marker" ;;
    esac
    ;;
  retry)
    # Start only work that never ran because of battery power or was cut
    # short. A job that ran and failed is not relaunched every interval.
    unit=$3
    if [[ -f $marker ]] && grep -qxE 'deferred|interrupted' -- "$marker"; then
      systemctl --no-block start "$unit.service"
    fi
    ;;
  *)
    echo "Unknown maintenance action: $action" >&2
    exit 2
    ;;
esac
