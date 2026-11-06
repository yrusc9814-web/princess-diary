# 2.0.0 重写进度（z衣橱 1.2.10 本地复刻）

## 阶段 1 — 数据层与服务（完成）
- lib/data/taxonomy.dart：系统衣物品类（两级）、翻牌槽位、18 色、状态/季节/风格/材质/保暖度/轮廓/长度/叠穿选项、内置品牌、模型标签映射
- lib/data/models.dart / db.dart：新库 schema v2（custom_cats, dicts, clothes, outfits, calendar, day_notes, trips, trip_outfits, trip_items, tryon_records）
- lib/data/migrate.dart：v1→v2 升级（旧表改名→建新表→转换→删旧表）；同一转换也用于导入 1.0 的 zip 备份
- services：settings（个性化/过滤设置/百炼 Key/上次导出）、tagger（本地 SigLIP2 → 中文字段）、weather（体感/降水/城市）、recommend（本地推荐引擎+过滤设置）、backup（.wrdx 导出/导入，兼容旧 zip）、tryon（百炼）、taobao（搜同款）
- widgets/common.dart、widgets/pickers.dart：通用组件与全部选择器
- 模型：保留开源 SigLIP2 + u2netp（docs/tagger_benchmark.md 实测优于原版 model_b，不换）
- 签名：原 debug keystore 已丢失（~/.android 不存在）→ 2.0.0 使用项目内固定 keystore（android/app/wardrobe-release.jks），以后升级可覆盖安装

## 阶段 2 — 页面（进行中）
- 页面全部写完（lib/pages/*）：首页+天气弹窗、单品列表/筛选/分组/⋮管理页、添加方式 sheet、编辑图片（裁剪/擦除/抠图）、添加/编辑单品（全部选填）、单品详情（3 Tab）、搭配列表/筛选/场合&标签管理、拼图画布、翻牌、智能搭配、添加/编辑搭配（3 Tab）、日历（选择单品/穿搭页、当天备注）、行程（空态/创建/详情）、我的、数据统计、素材库、个性化、自动搭配过滤设置、设置（百炼 Key）、数据迁移与备份、AI 试衣、批量添加、网页导入 + 扫描选图
- flutter analyze：0 error / 0 warning（仅 info）
- 1.0 旧页面源码备份在 build/v1_backup_src/pages（不参与编译）

## 阶段 3 — 打包（进行中）
- 首次 release 构建开始

- [10-28 18:40] 恢复：env 重装完成、pub get、patch_plugins、analyze 0 error（删 test 未用 import）；开始 release 构建 → /workspace/tools/build10.log
- [10-28 18:43] 合规检查：final-plan 各项均有实现；修 1.0 旧 zip 导入兼容（不再要求 version 字段；递归收集图片）。重启 release 构建 → build11.log
- [10-29 02:56 CST] 阶段 3 完成：release 构建成功（718s），versionName 2.0.0 / versionCode 2，签名证书 CN=MyWardrobe SHA-256 eab765da…6605（wardrobe-release.jks）。已复制到 outputs/我的衣橱_2.0.0_arm64.apk（223,424,962 字节，sha256 a636f9e0…c717）
- 安装说明：1.0 为丢失的 debug 签名，2.0 包名相同（com.mywardrobe.my_wardrobe）无法覆盖安装 → 先在 1.0「我的 > 导出备份」得到 zip，卸载 1.0，装 2.0，在「数据迁移与备份 > 导入备份包」选该 zip（导入走 convertV1 转换）

## 2.1.0 粉色主题（纯视觉换肤，功能/文案/结构不变）
- [10-30 01:05 CST] 开始：读 5 张参考图（files/uploads/ChatGPT 图像 2026年10月30日 00_48_2x-*.webp），盘点颜色常量（kPurple 100 处、kPurpleLight 15、kPurpleBg 6，主题在 lib/main.dart + lib/widgets/common.dart）
- [10-30 01:20 CST] 插画完成 → assets/illustrations/（rec_gift、empty_outfits 从参考图抠出；empty_clothes/trip/material/calendar/tryon/search、ov_tshirt/hanger/calendar/star 由 generate_image 生成，trip 重新抠绿）；pubspec 版本 2.1.0+3 + 资源目录。原始与中间文件在 work/theme/；2.0.0 源码备份 build/v2.0.0_src_backup/
- [10-30 01:40 CST] 主题层完成：common.dart 新粉色调色板（kRose/kRoseLight/kRoseBg/kPinkBorder…，kPurple* 全部改名为 kRose*）、AppCard/FormGroup/Tile/Pill/Toast/Sheet/EmptyState(支持插画) 换肤；main.dart ThemeData 全量粉色（ColorScheme 覆盖、AppBar/Nav/FAB/Dialog/Sheet/Chip/Switch/Slider/Tab/Checkbox/Radio/DatePicker/Segmented/Progress），PinkPageTransitions 给每页铺渐变底；work/theme/recolor.py 批量把冷灰/淡紫常量改为粉色系
- [10-30 01:55 CST] 5 个主 Tab 按参考图换肤完成：首页（概览四色点+插画图标+竖分隔、今天胶囊、粉色+格、换一换玫红、礼物盒插画、天气胶囊）、单品（分组卡片化、粉描边缩略图、FAB 主题化）、搭配（标题旁玫红智能搭配、衣架小兔空态）、日历（圆角格、今天粉格+玫红数字+小心形、日/六玫红、淡粉添加记录胶囊）、我的（粉渐变资料卡、白圆头像、图标粉方块、玫红箭头）
- [10-30 02:05 CST] 行程（行李箱插画空态、IconTile）、备份（警示卡改粉）、数据统计（粉系图表色板、顶部卡片）、翻牌（粉渐变、锁定胶囊、骰子按钮粉影）完成
- [10-30 02:15 CST] 素材库/选择单品&穿搭/智能搭配空态换插画；AI 试衣模特占位用试衣镜插画；编辑图片去白底；拼图/管理页卡片阴影粉化
- [10-30 02:25 CST] 详情/表单页自绘 Tab 改玫红+下划线，主图卡粉描边，设置页版本号显示 2.1.0；picker 选中框粉化
- [10-30 02:40 CST] flutter analyze：0 error / 0 warning（26 info）。新增 test/screens_test.dart（ffi DB + NotoSansSC 字体渲染截图到 test/goldens/），运行中
- [10-30 03:00 CST] 截图检查（test/goldens/1..18：5 主 Tab、统计、行程、素材库、AI 试衣、备份、设置、翻牌、添加方式 sheet、确认/输入对话框、天气 sheet、toast）：修分组标题被 Spacer 挤成省略号、FAB 64dp、对话框/底部弹窗遮罩改暖色、FormGroup 用 Material 承载背景（ListTile 水波可见）。注：测试环境 AppBar/按钮中文显示为方块是测试字体问题，真机系统字体正常。开始 release 构建 → /tmp/build21.log
- [10-30 01:46 CST] 2.1.0 构建成功（约 16 分钟）：applicationId com.mywardrobe.my_wardrobe，versionName 2.1.0 / versionCode 3，签名 CN=MyWardrobe SHA-256 eab765da…6605（与 2.0.0 相同 wardrobe-release.jks，可覆盖安装保留数据）。已复制到 outputs/我的衣橱_2.1.0_arm64.apk（225,682,853 字节，sha256 565a65ee…162d）
- 紫色审计：主题/页面中无紫色常量；剩余紫色仅为数据色（taxonomy 衣物颜色「紫色」色块、「多色」彩虹渐变）和用户允许的首页概览「衣物」小圆点 + 薰衣草色 T 恤图标（参考图同款）
- 2.1.0 粉色主题完成

## 2.1.1 图标与改名（无功能改动）
- [10-30 09:30 CST] 新启动图标：源图 files/uploads/image-6f2d5e43317f.webp（1254²）。裁掉外圈淡粉边与玻璃圆角框的边沿，取框内 (112,78)-(1142,1108) 1030² 区域（皇冠顶在 y≈108 仍完整）。脚本与中间文件 work/icon/make.py、art_crop.png、fg_master.png、legacy_master.png、round_master.png
  - 自适应图标：mipmap-anydpi-v26/ic_launcher.xml + ic_launcher_round.xml；前景 mipmap-*/ic_launcher_foreground.png（108dp 画布中放 80dp 图、下移 5dp，使皇冠顶落在 66dp 安全圆内，边缘羽化渐隐到背景）；背景 @color/ic_launcher_background = #FDCBDD（从框内粉色取样中位数），写在 values/colors.xml
  - 旧版图标：mipmap-mdpi…xxxhdpi 的 ic_launcher.png（圆角方形）与 ic_launcher_round.png（圆形），48/72/96/144/192px；Manifest 增加 android:roundIcon
  - 预览（方形/圆形遮罩/圆角遮罩/安全区示意/旧版圆形）：work/icon/icon_preview.png
- 改名「公主日记」：AndroidManifest android:label、MaterialApp title（lib/main.dart）、首页大标题（lib/pages/home_page.dart）、设置页「当前版本」副标题显示「公主日记」并显示 2.1.1。项目无 strings.xml。「单品」Tab 标题「我的衣橱」保持（属于衣橱栏目名）
- 未改：包名 com.mywardrobe.my_wardrobe、数据库 wardrobe.db、备份格式 .wrdx/.zip 与导入逻辑、签名 wardrobe-release.jks
- pubspec 2.1.1+4；flutter analyze 0 error / 0 warning（27 info，均为旧有）
- [10-30 ~09:55 CST] release 构建成功（969s）→ outputs/公主日记_2.1.1_arm64.apk（226,314,409 字节，sha256 4eed4df3e576906064cd3e9faceade6b0866a686789ac547984682c8fb16c25c）。aapt2 badging：label='公主日记' versionCode=4 versionName=2.1.1，icon→adaptive-icon（背景 #fffdcbdd + ic_launcher_foreground），各密度 PNG 均在包内；签名证书 CN=MyWardrobe SHA-256 eab765da…6605，与 2.1.0 一致，可覆盖安装保留数据
- 注：build-tools/36.0.0/aapt 为 x86 二进制无法运行，校验用 /workspace/tools/aapt2bin/aapt2 dump badging

## 2.1.2 文案微调（无功能改动）
- [10-30 ~10:20 CST] 「单品」Tab 页标题 lib/pages/wardrobe_page.dart:61「我的衣橱」→「我的单品」
- grep lib/ 全量「我的衣橱」：仅此 1 处，已无残留（其余「衣橱」为普通名词：衣橱概览、加入衣橱、全衣橱灵感、开始建立你的衣橱等，非 App 名，保持不变）。Android res 无「衣橱」文案
- 设置页版本号显示 2.1.2（lib/pages/settings_page.dart:36）；pubspec 2.1.2+5
- 未改：包名 com.mywardrobe.my_wardrobe、数据库 wardrobe.db、备份格式/文件名与导入兼容标识、签名 wardrobe-release.jks
- flutter analyze 0 error / 0 warning（27 info，均为旧有）
- [10-30 ~10:50 CST] release 构建成功 → outputs/公主日记_2.1.2_arm64.apk（226,314,409 字节，sha256 764375d9a281ff6208497c615e7d0320dd1a0960ecc21d899d6aa45cc421fc42）。aapt2 badging：label='公主日记' versionCode=5 versionName=2.1.2；apksigner 证书 CN=MyWardrobe, O=Personal, C=CN SHA-256 eab765dacec91be8f7234d9607c8a92d77cd0ccf6c25655766f597acb76f6605，与 2.1.1 一致，可覆盖安装保留数据

## 2.1.3 网页导入「扫描图片」修复（进行中：代码已改，待用户确认后再改版本号/构建）
- [10-30 ~12:50 CST] lib/pages/web_import_page.dart：_scanJs 重写（DOM <img>/<source>/srcset/懒加载属性按渲染尺寸 ≥100px、全部元素计算后 background-image ≥120px、开放 shadowRoot、同源 iframe、performance 资源记录 + onPageFinished 注入 PerformanceObserver/放大缓冲、HTML/内联脚本正则提取商品图 URL、≥200px 的 data:/blob: 内联大图）；过滤 -tps-WxH / !!6000000… / alicdn /tfs/ / 小尺寸后缀 / logo|icon… ；按商品路径+渲染尺寸排序，按去缩略后缀去重
- 选图页支持 data: 图（解码显示/导入），按真实尺寸隐藏 <160px 小图；扫描为空时弹窗：系统截图 → 「从相册选择」→ 编辑图片裁剪（webview_flutter Android 无截图 API，平台视图无法可靠截取，未做 WebView 截图）
- 无头 Chromium 测试结果与截图：work/scantest/RESULTS.md（测试商品本身被淘宝海外风控拦在登录页，改用真实海外 SSR 商品页 + 本地模拟页验证）
- flutter analyze 0 error / 0 warning（27 info，均为旧有）；pubspec 仍为 2.1.2+5，未构建

## 2.1.3 (versionCode 6) — 2026-10-30
- 淘宝扫描修复（web_import_page.dart）：记录加载过的图片、performance resource、computed 背景图、shadow DOM/iframe、源码图链、data/blob；过滤淘宝 UI 图标与小图；扫不到时提示截屏从相册导入。测试见 work/scantest/RESULTS.md（真实淘宝链接被海外 IP 拦，未在真实页面验证）。
- 我的页：「衣橱搭子」→「公主日记」，头像换为小公主 assets/illustrations/avatar_princess.png。
- 产物 outputs/公主日记_2.1.3_arm64.apk，226,510,105 bytes，SHA-256 eaaa15b3fbb3c4f635d9a3950b60d546a76e2b0097e8f871f25d4e85f5d65cd4，同签名 eab765da…6605。
