# z衣橱 1.2.10 APK 分析 (2026-10-28)
- 包名 com.ai.wardrobe；仅 arm64-v8a；无 v1 签名(v2/v3)；未发现加固壳
- Flutter 3.35.x (Dart 3.9.0, engine 2025-08-11)，release AOT，Dart 已混淆(libapp.so 无 package: 路径)；Java 层 R8 混淆；资源名混淆(res/HN.png 等)
- 后端 https://chuandaguanliapp.top/api （QQ互联 appid 102810386）；OSS 阿里云上海
- SDK：微信 fluwx(登录/支付)、QQ tencent_kit、阿里云号码认证/融合认证(alicom fusion, cmic/电信/联通)、极验 gt4、Google Play Billing、ONNX Runtime、geolocator、image_picker、ucrop、pro_image_editor、share_plus、open_file、sqlite3
- 端侧 AI：assets/models/model_b.ort 186MB = SigLIP 类 ViT-B 图像编码器(768维)；flutter_assets/assets/models/model_c.ort 4.8MB(疑似抠图/分割)；text_embeddings.json = 标签零样本分类(衣物分类/颜色/材质/保暖度/轮廓/长度/叠穿角色/风格/季节), vision_embed_v2
- 电商订单导入：淘宝/京东/拼多多/唯品会 webview (web_import 帮助图)

# 用户已有重写源码 wardrobe-android.zip (2026-10-28)
- 「我的衣橱·安卓自用版」Flutter，纯本地(SQLite)、无服务器/账号/会员，26 个 dart 文件约 3400 行，包名 com.mywardrobe.my_wardrobe
- 功能：今日推荐(Open-Meteo)、衣橱、添加衣物(本地 U²-Net 抠图)、详情、穿搭拼图、日历、出行装箱、统计、管理、AI试穿(百炼,可选)、zip 备份
- 打标：SigLIP2 base vision onnx(fp16权重,186MB)+自建 tag_embeddings.json；可选云端多模态覆盖
- 状态：flutter analyze 0 错误、推荐单测通过；从未打包 APK、未真机运行；百炼试穿接口未核对
- 原版有而它没有：登录/云同步、电商订单导入、微信/QQ 分享登录、会员支付、图片编辑器
- 风险：onnxruntime 插件 1.4.1 内置 ORT 1.15(旧, 不支持 q4)；186MB 模型使 APK 很大、首启需拷贝
