#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/lib/util.bash"

if [ "$#" -ne 2 ]; then
  echo_error "Usage: $0 <copy src> <output>"
  exit 1
fi

cpsrc=$1
out=$2

if [ ! -f "$out" ]; then
  echo_normal "Creating disk image: $out"
  block_size=1024
  dd \
    if=/dev/zero \
    of="$out" \
    bs=$block_size \
    count=$((2 * 1024 * 1024 * 1024 / block_size))
fi

echo_normal "Creating partition table on $out"
start_sector=2048
size=
type=0x0C # W95 FAT32 (LBA)
boot="*"
sfdisk "$out" 1>/dev/null <<EOF
  $start_sector,$size,$type,$boot
EOF

function copy()
{
  if [ "$#" -ne 2 ]; then
    echo_error "copy() requires 2 arguments"
    exit 1
  fi

  local src=$1
  local dst=$2

  # explicitly allow globbing
  mcopy \
    -i "$out"@@$((start_sector * 512)) \
    -o \
    -s \
    $src \
    "::${dst#/}"
}

echo_normal "Formatting partition as FAT32"
mkfs.vfat \
  -F 32 \
  -n "HUGIN" \
  --offset=$start_sector \
  "$out"

echo_normal "Setting up contents"
copy "$cpsrc/*" /

echo_normal "Done"
