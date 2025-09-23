#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/lib/qemu.bash"
source "$(dirname "$0")/lib/util.bash"

TIMEOUT=20
TMPFILE=$(mktemp)
MONITOR_SOCKET="/tmp/qemu-monitor-rtt-hid-$$"

# Success indicators.
HEYSTACK=(
  "[INFO ] main    | Switching to EL1h..."
)

# Check the num of arguments
if [ $# -ne 1 ]; then
  echo_error "Usage: $0 <uboot directory>"
  exit 1
fi
UBOOT_DIR=$1
echo_normal "Using U-Boot directory: $UBOOT_DIR"

# Check the output for expected strings.
function check_success()
{
  ret=0

  for needle in "${HEYSTACK[@]}"; do
    if ! (sed -e 's/\x1b\[[0-9;]*m//g' "$TMPFILE" | grep -qF -- "$needle"); then
      echo_error "Missing: '$needle'"
      ret=1
    fi
  done

  return $ret
}

_terminated=0
function cleanup() {
  if [ $_terminated -eq 1 ]; then
    return
  fi
  _terminated=1

  echo ""
  echo_normal "Cleaning up..."

  if [ -n "${QEMU_PID:-}" ] ; then
    qemu_exit
  fi
  rm -f "$TMPFILE" "$MONITOR_SOCKET"

  echo_normal "Cleanup done."
}
trap cleanup EXIT INT

function main()
{
  qemu_print_version

  qemu_start \
    "$(pwd)/zig-out/img" \
    "$MONITOR_SOCKET" \
    "$TMPFILE" \
    "$TIMEOUT" \
    "$UBOOT_DIR"
  qemu_wait

  echo ""

  if [ "$QEMU_RETVAL" -eq 124 ]; then
    echo_error "Timeout."
    exit 1
  fi
  local ret=$((QEMU_RETVAL >> 1))
  if [ $((ret << 1)) -ne 0 ]; then
    echo_error "QEMU exited with error code $ret."
    exit 1
  fi

  echo_normal "Checking output..."
  if ! check_success; then
    echo_error "Output does not contain expected strings."
    exit 1
  fi
  echo_normal "All expected strings found."
}

main "$@"
