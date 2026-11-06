# 我的衣橱 · 安卓自用版（Flutter）

按「z衣橱」的功能规格独立重写的自用版：数据全在手机本地，不需要服务器、不需要账号、没有会员。代码、界面和算法都是新写的，不含原 App 的代码、模型或素材。

## 功能
| 模块 | 文件 | 说明 |
|---|---|---|
| 今日推荐 | pages/home_page.dart | Open-Meteo 天气（免费、无需 Key）→ 规则打分推荐，左右滑，换一批，保存 / 就穿这套 |
| 衣橱 | pages/wardrobe_page.dart | 两级分类、排序（最新/常穿/久未穿/价格）、按状态/主色/季节筛选 |
| 添加衣物 | pages/clothes_edit_page.dart | 拍照或相册批量（最多 30 张）→ **手机本地抠图** → 识别 → 确认；手改字段记入 manualFields |
| 衣物详情 | pages/clothes_detail_page.dart | 全部属性、穿着次数、单次成本、"帮我搭配"（锚点搭配）、相关穿搭、状态、删除（清理关联）、AI 试穿 |
| 穿搭 | pages/outfits_page.dart / outfit_edit_page.dart | 选单品 → 拼图画布（拖动、双指缩放、置顶、6 种背景）→ 导出封面、分享；场合、标签；重复组合检测 |
| 穿搭日历 | pages/calendar_page.dart | 月视图，选穿搭或上身照记录，自动维护穿着次数 |
| 出行装箱 | pages/trips_page.dart | 按目的地 16 天预报每天配一套（上衣 2 天/件、下装 3 天/件、外套和鞋复用），勾选核对，自定义物品 |
| 统计 | pages/stats_page.dart | 总数、总价值、近 30 天新增、分类/颜色/季节/长度分布、穿着排行、从未穿过、90 天未穿、单次成本 |
| 管理 | pages/manage_page.dart | 分类（两级 + 搭配槽位）、衣物标签、穿搭标签、场合、品牌、收纳位置 |
| AI 试穿（可选） | pages/tryon_page.dart + services/tryon.dart | 阿里云百炼 aitryon / aitryon-plus，按张计费 |
| 备份 | pages/mine_page.dart | 导出 zip（数据库 JSON + 全部图片）用系统分享存到网盘，可一键恢复 |

## AI 能力怎么来的
| 能力 | 实现 | 费用 |
|---|---|---|
| 抠图 | 端侧 ONNX Runtime 跑开源 U²-Net（u2netp.onnx，Apache-2.0，约 4.6MB），离线 | 免费 |
| 主色 | 本地像素统计映射到 12 色 | 免费 |
| 分类/材质/季节/保暖/版型/长度/层次/风格 | 可选：任意 OpenAI 兼容多模态接口（通义千问 VL、GLM-4V、豆包视觉、自己的中转站），枚举约束输出 JSON；不配置则手选 | 每件约几厘钱 |
| AI 试穿 | 可选：百炼 aitryon 0.2 元/张、aitryon-plus 0.5 元/张，各 400 张免费额度；需北京地域 Key | 按张 |

## 构建 APK
1. 装 Flutter 3.24+（国内设置 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`、`PUB_HOSTED_URL=https://pub.flutter-io.cn`）、Android Studio / Android SDK、JDK 17。
2. 抠图模型 `u2netp.onnx` 已内置于 `assets/models/`（见该目录 README）。
3. `flutter pub get`
4. `flutter build apk --release --target-platform android-arm64`（自用可以直接用 debug 签名；输出在 `build/app/outputs/flutter-apk/app-release.apk`）。
5. 装到手机后：我的 → 设置，按需填识别接口和百炼 Key。

## 已验证 / 未验证
- 已在 Flutter 3.47.7 下 `flutter analyze` 0 错误；推荐算法 7 个单测全部通过（test/recommend_test.dart）。
- 未在真机上跑过，也未实际打包 APK（构建环境没有 Android SDK）。百炼试衣的上传/提交接口按官方文档格式实现，首次接入请对照百炼文档核对。

## 目录
```
lib/
  main.dart                 入口 + 底部 4 个 Tab
  data/consts.dart          属性枚举、默认分类
  data/models.dart          数据模型
  data/db.dart              SQLite 建表、增删改查、穿着次数维护、备份导入导出
  services/images.dart      图片保存/压缩/缩略图（应用私有目录）
  services/cutout.dart      端侧抠图
  services/tagger.dart      主色 + 可选多模态识别
  services/weather.dart     Open-Meteo 天气/地理编码
  services/recommend.dart   自动搭配算法（纯 Dart，可单测）
  services/tryon.dart       百炼 AI 试穿
  services/settings.dart    本地设置
  widgets/common.dart       通用组件 + 候选池
  pages/                    各页面
docs/spec.md                完整功能规格（给编码 agent 参考）
docs/AGENT_PROMPT.md        交给编码 agent 的任务说明
```
