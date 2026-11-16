# T216 总结：拼图里的「照片」支持裁剪

## 结论

做完了。拼图页底部工具栏在**选中照片**时多出「裁剪」按钮，点它才进裁剪页（选完照片仍然只是放到画布上，`_addPhoto` 没动）；裁剪页沿用 T215 的双指捏合缩放裁剪框 + 单指平移 + 四角把手，确认后直接带着裁好的图返回，只替换该元素的图片，位置/缩放/旋转不变，并压入撤销栈；再次裁剪从第一次裁剪前记下的完整原图开始，不会越裁越小。

- `flutter analyze`：**27 条 info，0 warning / 0 error**，与基线完全一致（唯一变化是原有的 `image_edit_page.dart:90` info 因代码上移变成 `:96`），新代码 0 新增 info。
- `flutter test` 全跑：**38 通过 / 1 失败**，失败的仍是 `screens_test.dart` 缺字体（`/tmp/shot_fonts/NotoSansSC-Regular.otf`，基线同样失败）；T215 的 `crop_math_test`（6 条）与 `t215_crop_gesture_test`（2 条）全部通过；新增 `t216_collage_crop_test` 10 条全通过。
- 只改了 `lib/pages/collage_page.dart`、`lib/pages/image_edit_page.dart`（只加一个可选参数 `cropOnly` 和裁剪后的返回路径），新增 `test/t216_collage_crop_test.dart`。没动包名/签名/pubspec 版本，没打包 APK，没 commit，没碰 `batch_add_page.dart`，T214/T215 的工作区改动原封不动。`pubspec.lock` 不在 diff 里。

## 改了什么

### 1. `lib/pages/collage_page.dart`

| 位置 | 改动 |
| --- | --- |
| `_El` | 新增可选字段 `String? original`；`toJson()` 多写 `'o'`，`fromJson` 用 `j['o'] as String?` 读，旧数据没有 `'o'` 时就是 `null`，不抛异常。 |
| `_selectedPhoto` getter | 只有当 `sel` 命中且 `els[i].kind == 'photo'` 才返回该元素，否则 `null`。工具栏和裁剪入口都用它判断，单品/文字天然被排除。 |
| `_cropPhoto()` | 新方法。`src = e.original ?? e.image`，`push<EditedImage>(ImageEditPage(path: ImageStore.abs(src), cropOnly: true))`；返回非空才 `e.original ??= e.image; e.image = r.image;` 然后 `_snap()`。返回 `null`（取消）直接 return，画布一点不变。位置/缩放/旋转字段完全不触碰，所以「位置/缩放/旋转不变」是结构性保证而不是靠赋值。 |
| 底部工具栏 | 在「背景」和「更多」之间插入 `if (_selectedPhoto != null) _tool(Icons.crop, '裁剪', _cropPhoto)`，沿用原来的 `_tool` 与粉色主题（`kRose` 为选中边框色，工具栏本身是白底黑图标，和现有 5 个按钮完全一致）。 |
| 新增 import | `import 'image_edit_page.dart';` |
| `collageJsonRoundTrip()` | `@visibleForTesting` 的小工具，把画布 JSON 走一遍 `_El.fromJson → toJson`，让测试能覆盖私有类的 JSON 往返。 |

`_addPhoto`、`_more`（含「复制」走 `_El.fromJson(toJson())`，因此复制时 `original` 一并复制）、`rotateDelta`、元素手势、T215 之前的改动都没改。

### 2. `lib/pages/image_edit_page.dart`（只加可选参数，老调用方零影响）

- 构造参数新增 `this.cropOnly = false`，原有 `path / newClothes / autoCutout` 不动。
- `initState` 里 `mode = widget.cropOnly ? 'crop' : '';`：cropOnly 进来直接是裁剪模式。
- `_applyCrop()`：先记住 `only = widget.cropOnly`，裁剪计算与原来自洽地跑完 `_setImage(out)` 后，如果是 `only` 就走 `_popCropped()` 直接 `Navigator.pop` 返回 `EditedImage(image, widget.path, thumb)`，不回到「编辑图片」工具页，也不走「下一步/添加单品」。非 cropOnly 路径与原来逐行一致。
- `_popCropped()`：新增，`savePng` + `makeThumb`，然后在 `mounted` 检查后 pop。
- 裁剪底栏：cropOnly 时左上角关闭按钮从「退出裁剪模式」变成「取消并返回上一页」（tooltip「取消」），确认按钮加了 tooltip「完成裁剪」；非 cropOnly 行为不变（仍然只 `mode = ''`）。
- T215 的 `_cropOverlay`（`scaleCrop`/`panCrop`、四个把手、`_cropBase`/`_cropPointers` 基准重置逻辑）**一行没动**。

### 3. `test/t216_collage_crop_test.dart`（新增，10 条）

- `_El` JSON 往返 3 条：带 `'o'`；不带 `'o'` 的旧数据（解析不炸、`o` 为 null、其他字段不受影响）；`'o'` 显式 null。
- 工具栏 5 条（真 widget 测试，起 `CollagePage`，`ImageStore.root` 指到临时目录）：未选中→无「裁剪」；选中照片→出现「裁剪」且其余 5 个工具都在；选中单品→无；选中文字→无；选中照片后点画布空白取消选中→「裁剪」消失。
- 裁剪入口 2 条：点「裁剪」后 `ImageEditPage` 的 `cropOnly == true` 且 `path` 是 `original`（不是裁过的图）；`ImageEditPage(cropOnly: true)` 一进来就出现裁剪框白边框、底部有「全图」没有「下一步」。

## 测试结果

```
flutter analyze  -> 27 issues found（全 info，0 warning / 0 error），与 T216-analyze-before.txt 逐条一致
flutter test     -> 00:10 +38 -1: Some tests failed.
                    唯一失败：test/screens_test.dart (setUpAll) PathNotFoundException:
                    /tmp/shot_fonts/NotoSansSC-Regular.otf —— 基线同样的失败，既有问题
```

明细见 `T216-analyze-before.txt` / `T216-analyze-after.txt` / `T216-test.txt`。基线 28 过 1 败 → 现在 38 过 1 败（新增 10 条）。

> 环境备注：一开始 `flutter analyze` 报 140 条、132 个 error（`sqflite`/`image`/`image_picker` 等 URI 不存在），是 `.dart_tool/package_config.json` 指向的 `~/.pub-cache` 包目录已被清空。执行一次 `flutter pub get` 后就恢复成文档里的基线 27 条 info；`pubspec.lock` 内容未变（`git status` 干净）。分析这一步必须做，否则基线和结果都没法比。

## 手机上怎么验证

1. 首页 → 拼图（新建穿搭拼图）。
2. 点「照片」选一张相册图：**照片直接出现在画布上，不会跳裁剪页**（这是本次要保证的行为）。
3. 点一下这张照片（出现粉色选中框 + 右上删除/右下缩放把手），底部工具栏**多出「裁剪」**（在「背景」和「更多」之间，剪刀图标）。
4. 点「裁剪」：直接进裁剪页（标题「裁剪」，图片上有裁剪框，底部是 取消 / 全图 / 裁剪 / ✓）。
   - 双指捏合：框放大缩小，图片不变形；单指拖：整框平移；拖四角白圆点：单独改某条边（T215 行为）。
   - 点 ✓：回到拼图页，照片变成裁好的图，**位置、大小、角度都和裁剪前一模一样**。
   - 再点「裁剪」：**又是完整原图**（不是上次裁剩的那块），可以重新框；反复裁几次也一样。
   - 进裁剪页后点左上 ×：回到拼图页，画布完全没变化。
5. 撤销（顶部 ↩）：裁剪前后各是一步，能来回。
6. 选中**单品**或**文字**：工具栏**没有**「裁剪」；点画布空白取消选中也没有。
7. 「更多 → 复制」复制一张裁过的照片：副本的图片和原图记录都跟着复制，副本再裁剪同样回到完整原图。
8. 保存退出后重新打开这条拼图：裁剪结果和原图记录都还在（`'o'` 已持久化到 `canvas` JSON）；打开更早版本存的拼图（没有 `'o'`）也正常显示，能继续裁剪。
9. 回归：从「衣橱 → 添加单品」走 `ImageEditPage` 的原流程不变（进的是「编辑图片」工具页，有裁剪/擦除/抠图 + 下一步）。

## 文件

- 改：`source/wardrobe-android/lib/pages/collage_page.dart`
- 改：`source/wardrobe-android/lib/pages/image_edit_page.dart`
- 新增：`source/wardrobe-android/test/t216_collage_crop_test.dart`
- 报告：`work/report/T216-summary.md`、`T216-diff.patch`（仅上述 3 个文件）、`T216-analyze-before.txt`、`T216-analyze-after.txt`、`T216-test.txt`
