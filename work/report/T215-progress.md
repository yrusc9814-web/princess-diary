# T215 进度
- 2026-11-14 16:20:08 读了 T215.task.md 与 image_edit_page.dart（404 行），确认 _cropOverlay 现状：crop 归一化 Rect + 4 角把手 + 框内 onPanUpdate(all:true)
- 2026-11-14 16:26:15 新增 lib/utils/crop_math.dart（scaleCrop/panCrop 纯函数）与 test/crop_math_test.dart，6 条纯函数测试全过
- 2026-11-14 16:28:08 改 image_edit_page.dart：整图 onScaleStart/Update 取代框内 onPanUpdate（1 指平移、2 指以焦点等比缩放+平移，基准框每次手势重置），4 角把手保留在上层
- 2026-11-14 16:28:08 flutter analyze 27 条 info，与基线逐条一致（仅 image_edit_page 一处既有 info 行号 +6），无新增 warning/error/info；flutter test 26 过 1 败（screens_test 缺字体，原有问题）
