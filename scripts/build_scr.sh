#!/bin/bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <uboot directory> <output>"
  exit 1
fi

uboot_dir=$1
output=$2

"$uboot_dir/tools/mkimage" \
  -A arm64 \
  -T script \
  -C none \
  -d assets/boot.txt \
  "$output"
