# 交给编码 agent 的任务说明（可直接粘贴）

你接手一个 Flutter 安卓应用「我的衣橱」（自用、纯本地、无后端）。代码已能通过 `flutter analyze`，推荐算法有单测。请在此基础上完成并打包：

1. 环境：Flutter stable、Android SDK、JDK 17。国内网络设置 FLUTTER_STORAGE_BASE_URL / PUB_HOSTED_URL 为 flutter-io.cn 镜像。
2. u2netp.onnx（开源，Apache-2.0）已内置于 assets/models/，无需再下载；不要使用任何第三方 App 安装包里的模型或素材。
3. `flutter pub get && flutter build apk --release --target-platform android-arm64`，在真机上逐项走一遍 README 的功能表，修复运行时问题（重点：onnxruntime 输出张量的解析、image_picker 权限、Android 13+ 照片权限、定位权限拒绝后的降级）。
4. 核对 services/tryon.dart 的百炼接口（临时上传 getPolicy、image-synthesis 异步任务、任务轮询）与阿里云百炼《AI试衣》官方文档一致。
5. 保持约定：数据只存本地 SQLite + 应用私有目录图片；用户手改过的识别字段写入 manualFields 不被覆盖；删除衣物/字典项要清理引用；日历记录增删要同步 wear_count / last_wear_date。
6. 可选增强（按优先级）：拼图里加文字/贴纸；衣物多选批量改状态；相似衣物去重（可接 qwen3-vl-embedding 或端侧小模型）；桌面小组件显示今日推荐。
完成后输出：APK 路径、真机测试清单（每项通过/失败）、改动说明。

补充（2026-10-17）：本地自动打标已接入。lib/services/clip_tagger.dart 用 assets/models/siglip2_vision.onnx（开源 SigLIP2，186MB）+ tag_embeddings.json 做零样本打标（9 组：品类→反推一级分类、主色、材质、保暖度、版型、长度、叠穿、风格、季节），由 lib/services/tagger.dart 调用；配置云端多模态时云端结果覆盖本地。参数与实测见 assets/models/README.md；改标签用 tools/gen_tag_embeddings.py 重新生成向量。不要使用原 App 的 model_b.ort / text_embeddings.json。真机需验证：首次启动拷贝模型到私有目录耗时、单张推理耗时（目标 <1s）、内存。验收门槛：用户 100 张自拍衣物，品类 ≥85%、主色 ≥80%。
