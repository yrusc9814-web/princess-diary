#!/bin/sh
# 在仓库根目录运行：sh big-files/restore.sh  —— 把切块的大文件合并回原位置并校验
set -e
cd "$(dirname "$0")/.."
while read sha path; do
  n=$(echo "$path" | tr '/' '__')
  mkdir -p "$(dirname "$path")"
  cat big-files/"$n".part* > "$path"
done < big-files/SHA256SUMS
sha256sum -c big-files/SHA256SUMS
