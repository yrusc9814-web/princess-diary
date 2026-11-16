# 公主日记（原 z衣橱 重写）— 交接说明

> 注意：大文件（APK、模型 siglip2_vision.onnx 等）在 big-files/ 里切块存放，先运行 `sh big-files/restore.sh` 还原。

> 给接手的 Agent：先通读本文件，再看 `history/聊天记录.md`（全部对话原文，最权威）。本文件是浓缩版。

## 1. 项目是什么
- 用 **Flutter** 重写安卓 App「z衣橱 1.2.10」（原包名 com.ai.wardrobe，AI 衣橱管理）。原 APK 是 Flutter AOT + 混淆，**无法还原源码**，所以是照功能和界面重写。
- 现名「**公主日记**」，**纯本地自用**，无后端、无登录。
- 当前已交付版本：**2.1.4（versionCode 7）**，`apk/公主日记_2.1.4_arm64.apk`（下一版 2.1.5+8）
  - 大小 226,510,105 bytes，SHA-256 `eaaa15b3fbb3c4f635d9a3950b60d546a76e2b0097e8f871f25d4e85f5d65cd4`
- **下一个版本必须用 2.1.4+7**（versionCode 只能递增）。

## 2. 关键身份（千万别改）
- 包名：`com.mywardrobe.my_wardrobe`
- 签名：`source/wardrobe-android/android/app/wardrobe-release.jks`
  - storePassword / keyPassword：`wardrobe2026`，alias：`wardrobe`（写在 `android/app/build.gradle.kts` 的 signingConfigs 里）
  - 证书 SHA-256：`eab765dacec91be8f7234d9607c8a92d77cd0ccf6c25655766f597acb76f6605`
- **包名或签名一变，用户手机上就不能覆盖安装，会丢数据。** 这个 jks 务必备份好。
- 告诉用户的安装方式：同包名同签名直接覆盖安装，数据保留；**不要先卸载**（卸载会清数据）；保险起见先在 App「备份」页导出。

## 3. 用户定下的规则和偏好（必须遵守）
- 回复用**中文**，技术术语用大白话解释。
- **先出方案、用户确认再动手**；改完代码**先测试、把结果给用户看，用户同意后才升版本号并打包**。不要自作主张打包。
- 打包很慢（约 16–20 分钟），小改动攒一起再打。
- 功能范围：原版功能全部重写，**只去掉登录**；依赖服务器的改本地实现（会员/积分去掉全开放、云备份→本地备份 zip、推荐本地算、素材自制）。删除消息/弹窗/埋点/兑换码。反馈页不做。数据统计、数据备份必须有（备份页显示上次导出时间）。
- AI 试衣：接**阿里云百炼试衣接口**，密钥在 App 设置里由用户填。
- 网页导入：内嵌 WebView 打开淘宝/京东/唯品会/拼多多，用户自己登录，点「扫描图片」抓商品图。
- 淘宝商品搜索：单品/搭配里的按钮，用「类别+颜色」关键词跳手机淘宝 App，没装则退回网页。
- 单品所有字段**选填**；没选品类归「未识别」，不禁用保存。品牌内置常见列表+可自定义。
- 模型：哪个好用用哪个，开源的更好就用开源的（现用 SigLIP2 + u2netp，见 docs/tagger_benchmark.md）。原版图标图片可复用；本地自用，用户说不涉及版权。
- 界面：布局与原版「几乎一致」（规格在 `notes/ui-screenshots.md`）。
- 主题：**只要粉色**（浅粉渐变底、半透明白卡片、玫红强调、底栏粉胶囊、粉色方形 FAB）。紫色彻底去掉，不做主题切换。插画在 `assets/illustrations/`。
- 命名：App 名「公主日记」（不带“衣橱”二字）；单品页标题「我的单品」；「我的」页原「衣橱搭子」已改为「公主日记」，头像是 `assets/illustrations/avatar_princess.png`。其他指衣服的“衣橱”词（衣橱概览等）保留。
- 图标：`original/uploads/image-6f2d5e43317f.webp`（粉发小公主），生成脚本 `work/icon/make.py`。

## 4. 版本历史
| 版本 | versionCode | 内容 |
|---|---|---|
| 1.0.0 | 1 | 用户原始自用版直接打包（debug 签名，钥匙已丢，不能被覆盖） |
| 2.0.0 | 2 | 原版功能全量重写；换固定签名 |
| 2.1.0 | 3 | 全 App 粉色主题 |
| 2.1.1 | 4 | 换图标，改名「公主日记」 |
| 2.1.2 | 5 | 单品页标题「我的单品」 |
| 2.1.3 | 6 | 淘宝新版商品页扫描修复（web_import_page.dart）；「我的」页改名+公主头像 |
| 2.1.4 | 7 | AI 试衣改百炼 qwen-image-3.0/pro；穿搭照点开预览；拼图旋转后拖动修复；单品裁剪双指缩放；拼图照片「裁剪」；每天凌晨 3 点自动备份（Documents/公主日记备份，只留最新一份）；备份文件改名 gongzhuriji_日期.wrdx。沙盒构建 |
| **2.1.4** | **7** | **下一个，待做（见第 5 节）** |

详细进度日志：`source/wardrobe-android/docs/REWRITE_PROGRESS.md`。

## 5. 进行中 / 未完成
### 5.1 批量导入 bug（代码已改，未 analyze、未测试、未打包）
- 用户朋友反馈：批量导入 10 张，处理中途删除一张（识别错了），剩下的全停了。
- 根因：`lib/pages/batch_add_page.dart` 的 `_process()` 用 `for (final it in items)` 遍历，中途 `items.remove` → `ConcurrentModificationError`，循环静默中断；剩余卡「等待处理」，保存按钮因 `done < items.length` 一直禁用，处理好的也存不了。只改品类/季节不会触发。
- 另一问题：处理中途按返回，未完成的图直接丢且无提示。
- 已改（当前源码里就是改后版本）：`while (!stopped)` 每次找下一张 state=='wait' 的项处理；`PopScope` + `_onBack()` 退出前 confirm 弹窗；保存后 `_saved=true`。
- 改前原文件：`work/batch_add_page.2.1.3.bak`（diff 可看改动）。
- **待办**：`flutter analyze` → 写/跑测试（含处理中删图、中途返回）→ 把结果给用户看 → 用户同意后版本改 2.1.4+7 打包。用户 11-04 晚说暂停，还没说继续。

### 5.2 淘宝扫描真机验证
- 用户给的真实链接 `https://e.tb.cn/h.jUUOWu0?tk=o1NwTzovZQZ`（商品 ID 1048161815972）在海外网络被淘宝重定向到登录/反爬页，沙箱里没验证到；只在可访问页面和本地仿新版页上测通（`work/scantest/RESULTS.md`）。已请用户手机实测，尚无反馈。

### 5.3 可选小优化（用户未要求）
- 概览淡紫T恤/蓝衣架图标、统计季节色块、删除红按钮改粉色；拼图画布、编辑图片、网页导入、单品详情/编辑这些页面未截图核对过主题。

## 6. 已回答过用户的问题
- 天气来源：Open-Meteo（免费免注册）；城市名反查 BigDataCloud；手动搜城市用 Open-Meteo 地理编码。低精度定位，缓存 1 小时，离线显示旧数据。气温误差一般 1–2 度，短时降雨不如中国天气/墨迹。

## 7. 构建（原沙箱环境，供参考）
原环境是 **aarch64 Linux 沙箱**，安卓工具多为 x86，靠 qemu 包装，所以很慢。**换到普通 x86 电脑/Mac 上构建会简单得多，不需要 qemu 和代理那套。**
- Flutter 3.47.8；Android SDK platform 36、build-tools 36、NDK 28.2；JDK 21。
- 国内镜像：`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`，`PUB_HOSTED_URL=https://pub.flutter-io.cn`。
- 步骤：`flutter pub get` →（原环境需要）`build-env/patch_plugins.sh` 把插件 compileSdk 提到 36 → `flutter build apk --release --target-platform android-arm64`。
- 需要按新机器修改的文件：
  - `android/local.properties`（sdk.dir / flutter.sdk 路径）
  - `android/gradle.properties`：删掉 `systemProp.http(s).proxy*` 四行（原沙箱本地代理）和 `android.aapt2FromMavenOverride` 一行（原 qemu 包装），内存参数可调大
  - `android/app/build.gradle.kts`：原沙箱里注释掉了 `ndkVersion`，正常环境可恢复
- `build-env/` 里是原沙箱脚本（env.sh、sysdeps.sh、localproxy.py、aapt2 包装等），只作参考。
- 已打包的 APK 约 226MB（主要是 assets/models 里的模型）。

## 8. 目录说明
- `source/wardrobe-android/`：**最新完整源码**（已去掉 build/.dart_tool 等可再生的编译产物）。内有 `docs/spec.md` 功能规格、`docs/AGENT_PROMPT.md`、`docs/REWRITE_PROGRESS.md` 进度、`docs/tagger_benchmark.md` 模型对比、`test/` 测试（含 screens_test.dart 截图测试）。
- `source/v2.0.0_src_backup/`：2.0 时的部分源码备份。
- `notes/`：原 APK 分析（apk-analysis.md、rea-analysis.md）、后端接口路径、原版全部中文文案、界面规格 ui-screenshots.md、最终方案 final-plan.md。
- `work/`：主题预览、图标脚本、扫描测试报告、批量导入改前备份。
- `history/聊天记录.md`：全部对话原文（按日期）；`history/daily_logs/`：每日工作摘要；`history/PROJECT_BRIEF.md`：原 Agent 的项目备忘。
- `apk/`：最新 2.1.4 安装包。
- `original/uploads/`：用户上传的全部原始素材——原版 z衣橱 1.2.10 APK、用户最初的重写源码 zip、原版界面截图和录屏（mp4）、粉色主题样图（ChatGPT 图像 *.webp 是正式 5 张；“甜美/粉色…”7 张是用户说发错的那批）、图标图。
