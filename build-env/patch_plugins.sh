#!/bin/sh
# bump plugin compileSdk to 36 (flutter_plugin_android_lifecycle requires it)
C=${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.flutter-io.cn
for f in $C/*/android/build.gradle $C/*/android/build.gradle.kts; do
  sed -i -E 's/^(\s*)compileSdk(Version)? (3[0-5])\s*$/\1compileSdk\2 36/; s/^(\s*)compileSdk(Version)? = (3[0-5])\s*$/\1compileSdk\2 = 36/' "$f"
done
