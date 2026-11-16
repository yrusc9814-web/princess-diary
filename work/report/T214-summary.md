# T214 总结（公主日记 2.1.4 三项修改）

## 结论

三项修改全部完成，验收意见中的 2 条新增 info 已清零、2 条 widget 测试已修复。

- `flutter analyze`：**27 条 info，与基线完全一致，新增 0 条**。
- `flutter test`：**20 过 / 1 败**，唯一失败是 `screens_test.dart` 的 `setUpAll` 缺 `/tmp/shot_fonts/NotoSansSC-Regular.otf` 字体（原有环境问题，非本次改动引入，按验收意见不处理）。
- `pubspec.lock` 未进入 diff，未打包 APK，未 commit/push，未碰 `lib/pages/batch_add_page.dart`。

## 改动文件与行数

| 文件 | 新增 | 删除 | 说明 |
| --- | --- | --- | --- |
| lib/services/tryon.dart | 114 | 50 | 第 1 项：重写为千问图像编辑同步接口 |
| lib/services/settings.dart | 13 | 1 | 第 1 项：tryOnModel 默认值与旧值迁移 |
| lib/pages/settings_page.dart | 13 | 19 | 第 1 项：模型选择弹窗改为遍历 `TryOn.models` |
| lib/pages/image_preview_page.dart | 112 | 0 | 第 2 项：新建全屏图片预览页 |
| lib/pages/outfit_form_page.dart | 9 | 3 | 第 2 项：穿搭照格子可点开预览 |
| lib/pages/collage_page.dart | 15 | 2 | 第 3 项：拖动位移按旋转换回屏幕坐标 |
| test/collage_rotate_test.dart | 44 | 0 | 新增：旋转换算单测 |
| test/image_preview_page_test.dart | 41 | 0 | 新增：预览页 widget 测试 |
| test/tryon_prompt_test.dart | 37 | 0 | 新增：拼指令图号单测 |
| test/tryon_settings_test.dart | 35 | 0 | 新增：模型旧值迁移单测 |

合计 10 个文件、433 行新增 / 75 行删除。

## 各项怎么改

### 第 1 项：AI 试衣换模型
- `tryon.dart` 改为 `POST https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation` 同步接口，只用 `Authorization: Bearer`（不带 `X-DashScope-Async`），请求体按 `input.messages[0].content` 排 `image`×N + `text`，`parameters` 为 `n/watermark/prompt_extend/negative_prompt`。
- 图片走 `data:{mime};base64,` 直接内联；原 `_upload`/`getPolicy`/`oss://` 上传与任务轮询全部删除。
- 结果从 `output.choices[0].message.content[]` 里取第一个带 `image` 的字段，立即下载成字节返回（URL 只 24 小时有效）。
- 新增 `TryOn.prompt({required bool hasTop, required bool hasBottom})` 静态函数，按件数拼图号；只有下装时是「图2中的下装」。固定尾巴文案按任务书原文。
- `run()` 签名未变（`tryon_page.dart` 不用改）。`onStep`：准备图片 → 生成中（标准版约 30 秒 / 高清版约 1 分钟）→ 下载结果。超时 4 分钟，报「生成超时，请检查网络后重试」。
- `friendlyError` 覆盖 InvalidApiKey / Arrearage / DataInspectionFailed / Throttling(.RateQuota) / AccessDenied(Model.AccessDenied)，其余为「生成失败：<message>」。
- `models` 常量、`tryOnModel` 默认 `qwen-image-3.0`，旧值 `aitryon-plus → qwen-image-3.0-pro`、`aitryon`/未知 → `qwen-image-3.0`。
- 文件顶部注释写明 aitryon/aitryon-plus 已于 2026-11 下架及千问图像编辑计价（输入 0.02 元/张、输出 0.18 元/张）。

### 第 2 项：穿搭照点开预览
- 新建 `ImagePreviewPage(images, initial)`：黑底、`PageView` 左右切换、`InteractiveViewer`（minScale 1 / maxScale 4）、双击在 1x 与 2.5x 间切换、顶部「当前/总数」+ 关闭按钮、`AppImage` + `BoxFit.contain`。
- `outfit_form_page._photos()` 穿搭照格子加 `onTap` push 预览，`initial` 为点击序号；右上角删除小叉用独立 `GestureDetector`/`InkWell` 包裹并保持原删除逻辑，点击不会被格子吃掉；加号格子行为未变。

### 第 3 项：拼图旋转后拖动方向错
- 采用任务书的最小改法：在 `collage_page.dart` 顶层抽纯函数 `Offset rotateDelta(Offset d, double rot)`（`sx = dx·cos − dy·sin`、`sy = dx·sin + dy·cos`）。
- `onScaleUpdate` 里先用**本次更新前**的 `e.rot` 把 `focalPointDelta` 换回屏幕坐标，再累加到 `e.x/e.y`，之后才用 `_startRot + d.rotation` 更新角度。
- 缩放旋转把手与删除叉未改动。

## 验收意见的修复

1. `lib/pages/image_preview_page.dart`：`Matrix4.identity()..scale(_doubleTapScale)` → `..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1)`，去掉 `deprecated_member_use`。
2. `test/collage_rotate_test.dart`：删掉多余的 `package:flutter/material.dart`（`Offset` 由 `flutter_test` 转出），去掉 `unnecessary_import`。
3. `test/image_preview_page_test.dart`：`setUpAll` 里给 `ImageStore.root` 赋一个 `Directory.systemTemp` 临时目录，避免 `LateInitializationError: Field 'root' has not been initialized`。**未改 `AppImage` 业务逻辑**，图片路径不存在时仍走原有 `errorBuilder` 占位。

## 测试结果

命令（在 `source/wardrobe-android`）：

```
export PATH=/workspace/tools/flutter/bin:$PATH PUB_HOSTED_URL=https://pub.flutter-io.cn \
       NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost
flutter analyze   > work/report/T214-analyze-after.txt   # 27 issues found（与基线一致）
flutter test      > work/report/T214-test.txt            # +20 -1
```

- 通过 20 条：`tryon_prompt_test` 4、`tryon_settings_test` 5、`collage_rotate_test` 6、`image_preview_page_test` 2、`migrate_test` 2、其余 1。
- 失败 1 条：`test/screens_test.dart (setUpAll)` — `PathNotFoundException: /tmp/shot_fonts/NotoSansSC-Regular.otf`，属既有环境缺字体，按验收意见不处理。

## 没做到 / 有风险

- **真实接口未联调**：没有百炼 Key，`tryon.dart` 的请求/响应解析只做了静态实现，未对真实服务发过一次请求；字段名按任务书约定，若线上返回结构有差异需再调。
- **千问模型名/计价**按任务书与文件头注释写入，未在控制台核实可用性。
- **第 2 项未补「点格子 → push 预览」的 widget 测试**：任务书列为可选（做不到要写原因）。该页依赖数据库与 `ImageStore`，在纯 widget 测试里搭不动，故未硬凑，仅用手工路径（`_photos()` 的 `onTap`）保证，未纳入自动测试。
- `flutter test` 里 `screens_test` 仍会因缺字体失败，需要时把 `NotoSansSC-Regular.otf` 放到 `/tmp/shot_fonts/` 即可，与本次代码无关。

## 交付物

- `work/report/T214-analyze-after.txt`（analyze 全量输出）
- `work/report/T214-test.txt`（test 全量输出）
- `work/report/T214-diff.patch`（`git add -N` 后的全量 `git diff`，638 行 / 10 个文件，含 5 个新文件）
- `work/report/T214-summary.md`（本文）
