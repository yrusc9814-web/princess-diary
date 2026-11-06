#!/bin/bash
# usage: run_bg.sh logfile cmd...
LOG=$1; shift
source /workspace/tools/env.sh >/dev/null 2>&1
cd /workspace/projects/55c223e2-85f0-4b17-a7fe-fcc7897abc14/build/wardrobe-android
( "$@" ; echo "EXIT_CODE=$?" ) > $LOG 2>&1
