# z衣橱 1.2.10 REA 复析 (2026-10-29)
工具：REA (rea-agents 6.7.0, /workspace/tools) + jadx-headless-mcp 0.7.1 (REA_JADX_MCP_JAR) + blutter (Dart 3.9.0 VM 已编译, /workspace/re/blutter)。输出 /workspace/re/{rea,out,jadx_out}
- APK sha256 8590677a…；versionCode 2027，minSdk 24，targetSdk 34，14 个权限，4822 个 Java 类
- Dart snapshot 97ff04a728735e6b6b098bdf983faaba = Dart 3.9.0；REA inspect-dart-aot 只能做字节级字符串池（不解析类/函数），需 blutter 补
- blutter：1914 个库全部混淆改名（AAn.dart…），但对象池字符串完整 → API 路径、中文 UI 文案、日志都在
- 上次结论“无法分析”过于保守：源码不可还原，但功能/接口契约可以基本完整反推
## 后端 API（base https://chuandaguanliapp.top/api，开发期 localhost:3000/api → Node 服务）
完整列表见 rea-api-paths.txt。分组：auth(手机号融合认证/微信/QQ/Apple/会话 prepare-activate-refresh)、agreements、clothes/outfits/occasions/brands/categories/storage-locations/clothes-tags/outfit-tags、sync(全量+增量按表同步)、images(register/embeddings/batch, 上传会话 upload-session/upload-complete)、ai-outfit(upload/generate/status/history/workflows，消耗积分)、points/balance/redeem/redemption-codes、vip/status、vip/cloud-backup、material-recommendations/feed、material-catalog-outfits/feed、materials/starter-pack、taobao/products(search/recommend)、collage-backgrounds/stickers、wearing-photos、user-model-images、weather/current、feedback、messages、popup、analytics/track/batch、app/version/latest
## 业务要点
- 本地 SQLite 为主 + 云端同步；会员=云备份与多端同步、无限单品/搭配数量（免费有上限）；“安卓暂不支持开通”
- 积分仅用于 AI 试衣；兑换码充积分
- 端侧：text_embeddings.json 零样本打标 + 图像 embedding 上传服务器（推荐/素材匹配用）
- 推荐：今日推荐按天气+温差+季节；“推荐搭配响应格式异常”说明至少部分推荐在服务端
- 淘宝：订单导入走 webview(web_image_import)；另有淘宝商品搜索/推荐（导购）
- 图片：抠图(AI 去背景, 批量≤30张)、擦除、pro_image_editor 编辑、拼图背景/贴纸
- 其它：出行清单、日历、统计(品牌/季节/保暖度分布、单次成本)、收纳位置、导出/导入备份包、反馈、消息、弹窗运营
## 细节补充
- 网页导入：内嵌 WebView 打开淘宝/京东/唯品会/拼多多 H5，用户自登录→订单列表→点“扫描”抓页面图片（alicdn.com / 360buyimg.com 等 CDN），勾选导入；可清除网页数据。纯本地可实现。
- AI 试衣：上传模特图(全身照)→涂抹要替换衣物的区域生成透明遮罩→选单品→服务端生成约2分钟→试衣记录。本地需接外部试衣 API（按次计费）。
