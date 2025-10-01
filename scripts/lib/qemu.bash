#!/bin/bash

[ -n "${H_GUARD_QEMU:-}" ] && return
readonly H_GUARD_QEMU=1

export QEMU_PID
export QEMU_RETVAL

source "$(dirname "$0")/lib/util.bash"

QEMU=qemu-system-aarch64

NUM_CORES=3
MEMORY=1G

declare -g _qemu_monitor_socket
declare -g _qemu_timeout
declare -g _qemu_start_time
declare -g _qemu_pidfile
declare -g _qemu_resultfile

function qemu_print_version
{
  echo_normal "QEMU version: $($QEMU --version | head -n 1)"
}

# Start QEMU.
#
# QEMU process ID will be stored in the global variable QEMU_PID.
#
# arg1: Path to the directory mounted as the root filesystem by EFI.
# arg2: Path to the UNIX socket for the QEMU monitor.
# arg3: Path to the log file for QEMU output.
# arg4: Timeout in seconds.
# arg5: u-boot directory.
function qemu_start()
{
  if [[ $# -ne 5 ]]; then
    echo "Usage: ${FUNCNAME[0]}(): <EFI root dir> <monitor socket> <log file> <timeout> <u-boot dir>"
    return 1
  fi

  local efi_root_dir="$1"
  _qemu_monitor_socket="$2"
  local log_file="$3"
  _qemu_pidfile="$3.pid"
  _qemu_timeout="$4"
  _qemu_resultfile="$3.result"
  _uboot="$5"
  local bios="$_uboot/u-boot.bin"

  echo_normal "Starting QEMU..."
  echo_normal "  EFI directory  : $efi_root_dir"
  echo_normal "  Monitor socket : $_qemu_monitor_socket"
  echo_normal "  Log file       : $log_file"
  echo_normal "  PID file       : $_qemu_pidfile"
  echo_normal "  Timeout        : $_qemu_timeout seconds"
  echo_normal "  Memory         : $MEMORY"
  echo_normal "  CPU cores      : $NUM_CORES"
  echo_normal "  BIOS           : $bios"

  tee "$log_file" < <(
    "$QEMU" \
        -M virt,gic-version=3,secure=off,virtualization=on \
        -smp "$NUM_CORES" \
        -bios "$bios" \
        -cpu cortex-a53 \
        -m "$MEMORY" \
        -nographic \
        -device virtio-blk-device,drive=disk \
        -drive file=./zig-out/diskimg,format=raw,if=none,media=disk,id=disk \
        -serial mon:stdio \
        -d guest_errors \
        -semihosting \
    2>&1 &
    local _qemu_pid=$!
    echo "$_qemu_pid" > "$log_file.pid"
    wait $_qemu_pid
    echo $? > "$log_file.result"
  ) &

  sleep 2
  QEMU_PID=$(cat "$_qemu_pidfile")
  _qemu_start_time=$(date +%s)

  if ! pgrep "qemu" > /dev/null; then
    echo_error "Failed to start QEMU."
    return 1
  fi
}

function qemu_sendkey()
{
  if [[ $# -ne 1 ]]; then
    echo_error "Usage: ${FUNCNAME[0]}(): <key>"
    return 1
  fi

  local key="$1"
  echo_normal "Sending key: $key"
  echo "sendkey $key" | socat - "$_qemu_monitor_socket"
}

# Send NMI command to QEMU.
function qemu_nmi()
{
  echo "nmi" | socat - "$_qemu_monitor_socket"
}

# Exit QEMU gracefully via QEMU monitor.
#
# If QEMU is not running, this function does nothing.
function qemu_exit()
{
  echo "quit" | socat - "$_qemu_monitor_socket"
  qemu_wait
}

# Kill QEMU process.
function qemu_kill()
{
  USE_SUDO=${1:-0}
  if [ "$USE_SUDO" -ne 0 ]; then
    if ! sudo kill -0 "$QEMU_PID" 2>/dev/null; then
      return
    fi
  else
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
      return
    fi
  fi
}

# Check if QEMU process is alive.
function is_qemu_alive()
{
  if kill -0 "$QEMU_PID" 2>/dev/null; then
    echo 1
  else
    echo 0
  fi
}

# Wait for QEMU to finish and capture its exit code.
# If timeout is reached, send NMI command to print stack traces.
#
# The exit code will be stored in the global variable QEMU_RETVAL.
function qemu_wait()
{
  USE_SUDO=${1:-0}

  local sleep_interval=1
  local timed_out=0

  while [ "$(is_qemu_alive)" -eq 1 ]; do
    local current_time=$(date +%s)
    local elapsed=$(( current_time - _qemu_start_time ))

    if [ $elapsed -ge "$_qemu_timeout" ]; then
      echo_normal "Timeout reached (${elapsed}s). Sending NMI command..."
      qemu_nmi
      timed_out=1
      sleep 1

      if [ "$(is_qemu_alive)" -eq 1 ]; then
        echo_normal "Killing QEMU..."
        qemu_kill "$USE_SUDO"
      fi

      break
    fi
    sleep $sleep_interval
  done

  QEMU_RETVAL=$(cat "$_qemu_resultfile" || echo 1)
  if [ -z "$QEMU_RETVAL" ]; then
    QEMU_RETVAL=-1
  fi

  # Timeout
  if [ $timed_out -eq 1 ]; then
    QEMU_RETVAL=124
  fi
}
