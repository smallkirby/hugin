#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/lib/qemu.bash"
source "$(dirname "$0")/lib/util.bash"

TIMEOUT=20
TMPFILE=$(mktemp)
MONITOR_SOCKET="/tmp/qemu-monitor-rtt-$$"

# Success indicators.
HEYSTACK=(
  # Hugin has booted.
  "[INFO ] main    | Hello from EL#2"
  # FAT32 filesystem has been parsed.
  "[DEBUG] fat32   | Found FAT32 filesystem @ LBA=0x800"
  "[DEBUG] fat32   |    OEM       : mkfs.fat"
  "[DEBUG] fat32   |    Revision  : 0.0"
  "[DEBUG] fat32   |    Root Clus : 2"
  "[DEBUG] fat32   |    Bytes/sec : 512"
  # Can read file from the FAT32 filesystem.
  "[DEBUG] main    | Hugin kernel ELF header magic is valid."
  # Boot Linux kernel.
  "Booting Linux on physical CPU"
  "Built 1 zonelists, mobility grouping on."
)

USE_SUDO=0
UBOOT_DIR=
EXPECT_TIMEOUT=0

function usage_exit()
{
  echo "Usage: $0 [--uboot <uboot directory>] [--use-sudo]"
  exit 1
}

# Parse arguments.
ARGS=$(getopt \
  --longoptions uboot:,use-sudo,expect-timeout \
  --options u:s \
  -- "$@" \
)
if [ $? -ne 0 ]; then
  usage_exit
fi
eval set -- "$ARGS"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -u|--uboot)
      UBOOT_DIR="$2"
      shift 2
      ;;
    -s|--use-sudo)
      USE_SUDO=1
      shift
      ;;
    --expect-timeout)
      EXPECT_TIMEOUT=1
      shift
      ;;
    --)
      shift
      ;;
    *)
      echo_error "Unknown argument: $1"
      usage_exit
      ;;
  esac
done

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

  if [ "$(is_qemu_alive)" -eq 1 ] ; then
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
    "$(pwd)/zig-out/diskimg" \
    "$MONITOR_SOCKET" \
    "$TMPFILE" \
    "$TIMEOUT" \
    "$UBOOT_DIR"
  qemu_wait "$USE_SUDO"

  echo ""

  if [ "$EXPECT_TIMEOUT" -eq 1 ]; then
    if [ "$QEMU_RETVAL" -ne 124 ]; then
      echo_error "Expected timeout, but QEMU exited with code $QEMU_RETVAL."
      exit 1
    fi
    echo_normal "Timeout as expected."
  else
    if [ "$QEMU_RETVAL" -eq 124 ]; then
      echo_error "Timeout."
      exit 1
    fi
    local ret=$QEMU_RETVAL
    if [ "$ret" -ne 0 ]; then
      echo_error "QEMU exited with error code $ret."
      exit 1
    fi
  fi

  echo_normal "Checking output..."
  if ! check_success; then
    echo_error "Output does not contain expected strings."
    exit 1
  fi
  echo_normal "All expected strings found."
}

main "$@"
