export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export ANDROID_HOME=/workspace/tools/android-sdk
export ANDROID_SDK_ROOT=/workspace/tools/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64
export PATH=/workspace/tools/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
export JAVA_TOOL_OPTIONS="-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=3128 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=3128 -Dhttp.nonProxyHosts=localhost|127.0.0.1"
export GRADLE_USER_HOME=/workspace/tools/gradle-home
export FLUTTER_SUPPRESS_ANALYTICS=true
pgrep -f localproxy.py >/dev/null || (cd /workspace/tools && nohup python3 localproxy.py >/tmp/lp.log 2>&1 &)
export PUB_CACHE=/workspace/tools/pub-cache
/workspace/tools/sysdeps.sh
export REA_JADX_MCP_JAR=/workspace/tools/jadx-headless-mcp-0.7.1-all.jar
