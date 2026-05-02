#!/usr/bin/env bash
# Whole-disk usage: total size from /sys/block; used = sum of df used on mounted partitions of that disk.
# Example: /dev/nvme0n1 130GB/931GB 14%
# Edit DISKS if you add another drive (e.g. DISKS=(/dev/nvme0n1 /dev/sda)).
set -uo pipefail

DISKS=(/dev/nvme0n1)

human_pair() {
  awk -v u="$1" -v t="$2" '
  function label(b,   x) {
    if (b >= 1099511627776) { x = b / 1099511627776; return sprintf(x >= 10 ? "%.0fTB" : "%.1fTB", x) }
    x = b / 1073741824
    return sprintf(x >= 100 ? "%.0fGB" : (x >= 10 ? "%.0fGB" : "%.1fGB"), x)
  }
  BEGIN {
    if (t <= 0) { print "?/?"; exit }
    printf "%s/%s", label(u), label(t)
  }'
}

disk_total_bytes() {
  local dev=$1 base=${dev##*/}
  [[ -r "/sys/block/$base/size" ]] || return 1
  local sectors
  sectors=$(cat "/sys/block/$base/size")
  echo $((sectors * 512))
}

disk_used_sum_bytes() {
  local disk=$1
  local sum=0 mp u fst
  while read -r mp; do
    [[ -z "$mp" ]] && continue
    [[ "$mp" == "[SWAP]" ]] && continue
    fst=$(findmnt -n -o FSTYPE "$mp" 2>/dev/null || true)
    [[ "$fst" == "tmpfs" || "$fst" == "devtmpfs" || "$fst" == "squashfs" ]] && continue
    u=$(df -P -B1 "$mp" 2>/dev/null | awk 'NR==2 {print $3}')
    [[ -n "${u:-}" ]] && sum=$((sum + u))
  done < <(lsblk -nr -o MOUNTPOINT "$disk" 2>/dev/null | sort -u)
  echo "$sum"
}

chunks=()
for dev in "${DISKS[@]}"; do
  [[ -b "$dev" ]] || continue
  total_b=$(disk_total_bytes "$dev") || continue
  [[ -z "${total_b:-}" || "$total_b" -le 0 ]] && continue
  used_b=$(disk_used_sum_bytes "$dev")
  pair=$(human_pair "$used_b" "$total_b")
  pct=$(awk -v u="$used_b" -v t="$total_b" 'BEGIN { if (t<=0) print 0; else printf "%.0f", 100*u/t }')
  chunks+=("$dev $pair ${pct}%")
done

if ((${#chunks[@]} == 0)); then
  echo "—"
  exit 0
fi

out="${chunks[0]}"
for ((i = 1; i < ${#chunks[@]}; i++)); do
  out+=" · ${chunks[i]}"
done
echo "$out"
