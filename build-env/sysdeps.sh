#!/bin/sh
# reinstall system deps after sandbox reset
command -v java >/dev/null && [ -e /lib64/ld-linux-x86-64.so.2 ] && command -v cmake >/dev/null && exit 0
sudo -n dpkg --add-architecture amd64 2>/dev/null
sudo -n apt-get update -qq 2>/dev/null
sudo -n apt-get install -y -qq openjdk-21-jdk-headless qemu-user-static xz-utils zip cmake ninja-build libc6:amd64 libstdc++6:amd64 zlib1g:amd64 >/tmp/sysdeps.log 2>&1
