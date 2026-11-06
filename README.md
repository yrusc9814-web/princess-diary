# 公主日记（princess-diary）

用 Flutter 重写的本地 AI 衣橱管理安卓 App（原 z衣橱 1.2.10）。纯本地、无登录、粉色主题。

**接手请先读 [HANDOVER.md](HANDOVER.md)**，完整对话在 `history/聊天记录.md`。

## 大文件
GitHub 单文件上限 100MB，以下文件切块存放在 `big-files/`，克隆后在仓库根目录运行 `sh big-files/restore.sh` 合并还原（会自动校验 SHA-256）：
- `apk/公主日记_2.1.3_arm64.apk`（最新安装包）
- `source/wardrobe-android/assets/models/siglip2_vision.onnx`（识别模型，**构建前必须还原**）
- `original/uploads/z衣橱_1.2.10-*.apk`（原版 APK）
- `original/uploads/wardrobe-android-*.zip`（用户最初的重写源码）

⚠️ 仓库含签名文件 `source/wardrobe-android/android/app/wardrobe-release.jks` 及密码，务必保持私有。
