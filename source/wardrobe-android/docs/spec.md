# z衣橱 1.2.10 拆解与复刻规格（交付编码 agent 用）

> 用途：把对安卓 App「z衣橱」1.2.10（包名 com.ai.wardrobe）的静态分析结果，整理成可独立实现的产品与技术规格，目标平台为**微信小程序（默认原生 + 微信云开发）**。
> 边界：本文只描述功能、行为和数据形态，不含任何反编译源码、密钥、原 App 图片/图标/文案素材；接口按我们自己的后端重新设计，仅参考原 App 的接口"形态"。实现时请自行设计 UI、文案与视觉。
> 证据等级：✅ 直接由安装包内字符串/资源证实；🔶 由字段名、埋点名推断；❔ 合理猜测，需产品自行决定。

---

## 0. 拆解结论速览

| 项 | 结论 |
|---|---|
| 产品定位 | 个人电子衣橱 + 智能穿搭：拍照/导入衣物 → 自动抠图与打标 → 管理衣橱 → 按天气/场合自动搭配 → 穿搭日历、出行装箱、AI 试衣 |
| 客户端技术栈 | Flutter（Dart AOT，`libapp.so` + `libflutter.so`），仅 arm64-v8a；minSdk 24 / targetSdk 34；versionCode 2027 ✅ |
| 本地存储 | SQLite（drift + sqflite）、shared_preferences、文件缓存 ✅ |
| 端侧 AI | ONNX Runtime 跑两个模型 ✅：① ~186MB 的 ViT-B 图像编码器（带 attention pooling，结构类似 SigLIP，输出 768 维 L2 归一化向量）；② ~4.8MB 的 U²-Net 轻量版显著性分割模型（抠图/去背景） |
| 零样本打标 | 内置一份"标签文本 → 768 维文本向量"表，覆盖 9 个维度：衣物分类(260 条同义词)、颜色(12)、材质(38)、保暖度(25)、轮廓(24)、长度(21)、叠穿角色(17)、风格(49)、季节(26)；用图像向量与文本向量做余弦相似度完成自动打标 ✅ |
| 服务端 AI | AI 试衣（上传本人模特照 + 选衣物/穿搭 → 后端工作流生成，约 2 分钟，消耗积分）✅；AIGC 内容标识水印（按 TC260 AIGC 元数据规范写入）✅ |
| 后端 | 自建 REST API（`/api` 前缀，开发期为 Node 风格 3000 端口），图片存阿里云 OSS（上海）✅ |
| 登录 | 阿里云号码认证（一键登录/短信）、微信、QQ、Apple；极验 v4 行为验证 ✅ |
| 商业化 | 积分（AI 试衣）、会员/云备份（虚拟商品）、兑换码、淘宝联盟商品推荐（带券价/佣金字段）✅ |
| 其他 SDK | 微信 SDK（fluwx，分享/登录/支付回调）、QQ（tencent_kit）、Google Play Billing / StoreKit（in_app_purchase）、定位（geolocator）、图片裁剪（ucrop/image_cropper）、图片编辑器（pro_image_editor）、图表（fl_chart）、日历（table_calendar）、瀑布流、截图分享 ✅ |

---

## 1. 产品概述

一句话：**"把衣柜搬进手机，每天告诉你穿什么。"**

核心价值链：
1. **低成本录入**：拍照/相册批量导入/电商订单截图导入 → 自动去背景 → 自动识别分类、颜色、材质、季节、保暖度等。
2. **结构化管理**：分类（两级，可自定义）、标签、品牌、收纳位置、购买价格/日期、穿着次数。
3. **智能搭配**：基于天气（定位 + 实时天气 + 当日温差）、季节、叠穿层次、颜色与风格兼容度、近期穿着轮换，生成"今日推荐"，可左右滑动换一套。
4. **记录与复盘**：穿搭日历、上身照、统计（衣橱概览、长期未穿、穿着排行、长度/颜色分布等）。
5. **场景工具**：出行装箱清单（行程 + 智能补全 + 勾选核对）、穿搭拼图（画布 + 背景 + 贴纸，导出分享图）。
6. **增值**：AI 试衣（积分）、云备份与多端同步（会员）、素材库/商品推荐（电商导购）。

主导航（推断 🔶）：首页（今日推荐 + 天气）／衣橱／穿搭／我的。

---

## 2. 页面与功能清单 + 行为规格

下列每个功能按「入口 / 交互 / 状态 / 边界 / 文案要点」描述。页面名为建议命名。

### 2.1 首页 Home（今日推荐）
- **入口**：Tab 1。
- **内容**：天气卡片（当前温度、天气现象、当日最高/最低）；"今日推荐"搭配卡片 1~N 套；会员/权益卡（可选）；空衣橱时显示新手引导（添加衣物、导入）。✅
- **交互**：
  - 首次进入请求定位授权；拒绝则提示手动选城市或用默认城市（✅ 有"定位提示展示"埋点）。
  - 天气按缓存优先：同一城市 1 小时内用缓存，失败时用上次快照并标记"可能不准"（✅ weather_from_local_cache / weather_confidence_low）。
  - 推荐卡片可左右滑动/点"换一套"；收藏为我的穿搭；点"今天穿这套"写入穿搭日历并给每件衣物 wear_count+1、更新 last_wear_date。
  - 推荐理由标签：如"适合今天温度""根据最近天气和今日温差推荐"。✅
- **状态**：加载中 / 有推荐 / 推荐不足（"今天可推荐的搭配不多"）/ 衣橱为空（"衣橱里还没有可搭配的单品"）/ 天气失败（可重试）。✅
- **边界**：可搭配单品不足（无上装或无下装且无连衣裙）→ 引导补录；所有候选被过滤设置排除 → 提示去"自动搭配过滤设置"。

### 2.2 衣橱 Wardrobe
- **入口**：Tab 2。
- **展示**：按分类分组（横向分类条 + 网格），支持切换分组模式：按分类 / 按颜色 / 按季节 / 按收纳位置 🔶（clothes_home_group_mode、color_clothes_page、sub_category_clothes_page）。
- **筛选**：分类、颜色、季节、标签、品牌、收纳位置、状态（在穿/闲置/已处理 ❔）；显示当前生效筛选数量。✅ active_filters_count
- **排序**：手动拖拽排序（✅ /clothes/order、reorderables）、按添加时间、按穿着次数、按最近穿着。
- **显示偏好**：是否显示衣物名称、是否显示淘宝/来源角标。✅ show_clothes_name / show_taobao_badge
- **批量操作**：多选 → 删除 / 改分类 / 改收纳位置 / 分享。
- **空状态**：引导"开始建立衣橱"，提供 拍照 / 相册批量 / 订单截图导入 三个入口。✅

### 2.3 添加衣物（单件）Clothes Add/Edit
- **入口**：衣橱右上"+"、首页引导、详情页"编辑"。
- **流程**：
  1. 选图（拍照/相册），可裁剪、旋转。
  2. 自动去背景（抠图），生成透明底 PNG + 缩略图；用户可"恢复原图"或手动擦除/修补（✅ erased_image、edited_image、批量添加页自动去背景）。
  3. 自动识别：分类（一级/二级）、主色（含 HEX 与置信度）、材质、季节（多选）、保暖度、轮廓、长度、叠穿角色、风格。用户手动改过的字段打 `manually_selected` 标记，之后不再被自动结果覆盖。✅ category_manually_selected / seasons_manually_selected
  4. 补充信息：名称、品牌（可新建）、价格、购买日期、收纳位置、标签、备注、是否参与自动搭配（✅ affects_auto_outfit："关闭后则不参与搭配"）。
  5. 保存：先本地落库再后台上传图片与数据；失败进入重试队列。✅
- **边界**：识别到系统中不存在的新分类时，提示"是否添加为自定义分类"（可在设置关闭此提醒）✅；疑似重复衣物（向量相似度高）提示 ✅ duplicate_clothes；图片过大先压缩（建议长边 ≤1600px，缩略图 ≤400px）。
- **文案要点**：识别仅供参考、可随时修改；保存失败保留已填写内容。

### 2.4 批量添加 Batch Add
- 两步：① 多选图片（建议上限 30/次）→ 逐张抠图 + 识别，显示进度与失败项；② 列表确认/修改每件的分类与季节后一键保存，结果汇总"成功 X / 失败 Y"。✅ batch_add_clothes_screen_step2、batch_clothes_save_summary
- 失败项可重试或剔除："部分图片准备失败，请重试或取消选择失败图片"。✅

### 2.5 网页/订单导入 Web Import 🔶
- 原 App：内置 WebView 打开电商站点（淘宝/京东/拼多多/唯品会）让用户登录后在"我的订单"截取商品图导入，并附 4 步图文帮助；可"清除网页数据/退出购物账号"。✅
- **小程序复刻建议**：小程序无法内嵌第三方电商登录页，改为 **"订单截图导入"**：用户上传订单截图 → 服务端用版面检测/多模态模型框出商品图与标题、价格 → 生成待确认衣物列表。这是独立实现，不抓取第三方站点。

### 2.6 衣物详情 Clothes Detail
- 大图（透明底，可切换原图）、全部属性、穿着次数、最近穿着日期、单次穿着成本（价格 ÷ 次数 ❔）。
- Tab：「包含此衣物的穿搭」「以此为中心自动搭配」（✅ clothes_detail_auto_outfit_generated，锚点衣物 anchor_clothes）「上身记录」。
- 操作：编辑、删除（同时清理与穿搭/日历/行程的关联，✅ cleanupClothesRelations）、开关"参与自动搭配"、分享。

### 2.7 我的穿搭 Outfits
- 列表（瀑布流卡片：拼合图或上身照），按场合/标签/季节筛选。✅ occasion_outfit_page、outfit_tag
- **新建穿搭**两种方式：
  - 选单品组合：多选衣物 → 自动生成拼合预览 → 填名称、场合（多选）、标签、季节 → 保存。"请至少选择一件衣物"。✅
  - 从照片创建：选一张上身照 → 关联涉及的衣物（可选）→ 保存。✅
- 详情：拼合图/上身照、单品清单（点进衣物详情）、场合、标签、穿着记录；可"移除单品"、"加入日历"、"分享"。

### 2.8 穿搭拼图 Collage
- 画布：添加衣物透明图、贴纸、文字；拖动/缩放/旋转/层级；预设背景切换（✅ collage-backgrounds、collage-stickers、bg_index）。
- 导出 PNG 保存相册或分享海报。

### 2.9 自动搭配 / 刷搭配 Auto Outfit & Swipe
- **独立自动搭配页**：一次生成 N 套候选，卡片式左滑跳过、右滑保存（✅ outfit_swipe、swipe_confirm、usage_summary）。
- **自动搭配过滤设置**：只用当季衣物（✅ all_closet_season_only）、排除某些系统分类（✅ excluded_system_categories）、排除指定衣物。
- 生成逻辑见 §6.3（我们自己的算法设计）。
- 状态：生成中 / 无可用候选（no_eligible_outfits）/ 已看完当日批次（"暂时没有更多可换"）。

### 2.10 穿搭日历 Calendar
- 月视图，每天显示当天穿搭缩略图；点日期进"日视图"：可添加/更换穿搭、添加单件衣物、上身照、当天备注。✅ outfit_calendar_day、day_notes
- 规则：同一天可多条（如通勤 + 晚宴）❔；写入/删除时同步维护衣物 wear_count 与 last_wear_date（✅ supplemental_wear_count）。
- 边界：选未来日期 = 计划穿搭；开始日期不能晚于结束日期（用于区间查看）。✅

### 2.11 出行装箱 Trips
- 行程列表 → 新建行程：名称（必填）、目的地、开始/结束日期、备注。✅
- 行程详情：每日穿搭计划 + 装箱清单；"智能推荐，补全出行装备"（按目的地天气与天数推算需要的上装/下装/外套数量并从衣橱挑选）✅；
- 装箱勾选：每放入一件勾选一件，显示进度。✅ trip_item_state
- 删除行程需二次确认。

### 2.12 统计 Analytics
- 衣橱概览：总件数、总价值、近 30 天新增（✅ clothes_count_30）、各分类/颜色/季节/长度分布（✅ 长度分布）。
- 穿着分析：穿着排行（✅ wear_top_view_all）、长期未穿/从未穿过（✅ wear_cold_view_all、"从未穿过"、"最近较少穿"）、单次穿着成本。
- 图表：饼图、柱状图（原 App 用 fl_chart）。

### 2.13 基础数据管理（设置内）
- 自定义分类（两级，可排序；删除时提示"可能影响已使用该分类的衣物"）✅
- 衣物标签、穿搭标签、场合、品牌、收纳位置：增删改排序，删除前提示影响范围。✅
- 颜色：12 个基础色可修正。

### 2.14 AI 试衣 Try-on
- 前置：登录；上传 1~N 张本人全身照作为"模特图"（✅ user-model-images），提示拍摄要求（正面、站立、光线均匀、单人）。
- 选择：一套穿搭或若干单品（上装+下装 或 连衣裙）。✅ ai_outfit_select_clothes / select_outfits
- 提交 → 扣积分 → 异步生成（"生成中（约2分钟）"）→ 轮询状态 → 结果图带 AI 生成标识水印 → 可编辑/保存为穿搭/加入日历。✅
- 历史记录列表，可按衣物或穿搭查看。✅ ai-outfit/records/clothes, /outfit
- 边界：积分不足 → 去获取积分；生成失败自动退还积分 ❔（建议）；内容审核不通过的提示。
- 合规：结果图需显式标注"AI 生成"（可见水印）+ 文件元数据隐式标识（《人工智能生成合成内容标识办法》）。

### 2.15 素材库 / 商品推荐 🔶
- 官方提供的单品素材库（starter pack），新用户可一键把常见基础款加入衣橱，用于先体验搭配。✅ materials/starter-pack、material_library_batch_add
- "灵感穿搭"信息流：官方穿搭（由素材单品组成），可一键保存；"基于我的衣物推荐"相似商品，可跳淘宝。✅ material-recommendations/by-clothes、taobao/products/recommend
- 小程序复刻：电商导购需接入淘宝联盟/京东联盟官方开放平台，或首版不做。

### 2.16 我的 / 账号 / 会员
- 登录方式：手机号（一键/短信）、微信、QQ、Apple；可绑定多种方式；注销账号。✅
- 积分：余额、明细、获取途径；兑换码兑换。✅
- 会员 / 云备份：开通状态、已备份百分比、手动同步、导出备份包（"卸载/换机记得导出备份"）。✅
- 消息中心 / 反馈：提交建议或问题（可带截图），查看历史与官方回复，未读角标。✅
- 协议：用户协议、隐私政策、首次启动隐私同意（✅ agreements/status）。
- 弹窗运营位：展示/点击上报。✅ popup/shown, popup/action

---

## 3. 主要用户流程

1. **新用户冷启动**：同意隐私 → 微信登录 → 空衣橱引导 → 批量添加 10~20 件（自动抠图识别）→ 确认保存 → 首页出现今日推荐。（备选：从素材库一键添加基础款先体验）
2. **每日穿搭**：打开首页 → 看天气与推荐 → 滑动换一套 → "今天穿这套" → 日历记录、穿着次数更新。
3. **整理衣橱**：衣橱筛选"从未穿过/近 90 天未穿" → 批量改状态或删除 → 统计页查看变化。
4. **出行**：新建行程（目的地+日期）→ 智能补全装备 → 微调 → 出发前逐件勾选。
5. **AI 试衣**：上传模特照 → 选一套穿搭 → 扣积分提交 → 2 分钟后收到结果（订阅消息通知）→ 保存。

---

## 4. 数据模型（云开发集合设计）

通用字段：每个集合都有 `_id`、`_openid`（云开发自动）、`createdAt`、`updatedAt`（服务器时间）、`deletedAt`（软删除，便于同步）。

### 4.1 users
| 字段 | 类型 | 说明 |
|---|---|---|
| nickname, avatar | string | |
| phone | string? | 绑定手机号（经微信手机号组件获取） |
| points | int | 积分余额（只能云函数改） |
| vip | {level, expireAt} | 会员 |
| settings | object | 见下 |
| agreementsVersion | string | 已同意协议版本 |

`settings`：`autoOutfit: {seasonOnly: bool, excludedCategoryIds: [], excludedClothesIds: []}`、`display: {showClothesName, groupMode}`、`promptNewCategory: bool`、`city`（手动城市）。

### 4.2 clothes（衣物）
| 字段 | 类型 | 说明 |
|---|---|---|
| name | string | 可空，默认用二级分类名 |
| images | {original, cutout, thumb} | 云存储 fileID |
| categoryL1Id / categoryL2Id | string | 指向 categories |
| colors | [{name, hex, ratio}] | 主色在前 |
| colorConfidence | number | |
| materials | string[] | 棉/羊毛/牛仔… |
| seasons | string[] | spring/summer/autumn/winter |
| warmth | enum | thin / medium / warm / very_warm |
| fit | enum | slim / regular / loose(oversized) |
| length | enum | short / regular / long / extra_long |
| layerRole | enum | base / mid / outer（鞋包配饰为 none） |
| styles | string[] | casual / commute / sport / street / … |
| brandId | string? | |
| price | number? | 元 |
| purchaseDate | date? | |
| storageLocationId | string? | |
| tagIds | string[] | |
| note | string | |
| status | enum | active / idle / disposed |
| inAutoOutfit | bool | 是否参与自动搭配，默认 true |
| manualFields | string[] | 被用户手改过的属性名，自动识别不再覆盖 |
| wearCount | int | |
| lastWearDate | date? | |
| embedding | number[]? | 图像向量（可选，存独立集合更好，见 4.10） |
| source | enum | camera / album / screenshot / material |
| sortOrder | number | 手动排序 |

### 4.3 outfits（穿搭）
| 字段 | 类型 | 说明 |
|---|---|---|
| name | string | |
| items | [{clothesId, rankInOutfit, layout?: {x,y,scale,rotate,z}}] | 单品与拼图布局 |
| coverImage | fileID | 拼合图或上身照 |
| photos | fileID[] | 上身照 |
| occasionIds, tagIds | string[] | |
| seasons | string[] | 可自动由单品推出，也可手改 |
| source | enum | manual / photo / auto / tryon / material |
| score | number? | 自动搭配得分（展示用） |
| wearCount, lastWearDate | | |

### 4.4 categories（两级分类）
`name, parentId(null=一级), system(bool), slot(top|bottom|onepiece|outer|shoes|bag|accessory), sortOrder`。系统分类不可删，可隐藏。

### 4.5 tags / outfitTags / occasions / brands / storageLocations
统一结构：`name, sortOrder, color?`；clothes/outfits 通过 id 数组引用。删除时云函数同步把引用移除。

### 4.6 calendarEntries（穿搭日历）
`date(YYYY-MM-DD), outfitId?, clothesIds[], photos[], note, weatherSnapshot{temp,max,min,text}`。约束：写入/删除时增减相关衣物 wearCount。

### 4.7 trips / tripItems
- trips：`name, destination{city, lat, lng}, startDate, endDate, note, days[{date, outfitId?}]`
- tripItems：`tripId, clothesId?, customName?, qty, packed(bool), sortOrder`

### 4.8 tryonJobs（AI 试衣）
`modelImageId, clothesIds[], outfitId?, status(pending|running|succeeded|failed|refunded), pointsCost, resultImage, errorCode, provider, createdAt, finishedAt`

### 4.9 modelImages / pointsLedger / feedback / redeemCodes
- modelImages：`fileId, isDefault`
- pointsLedger：`delta, reason(signup|redeem|tryon|refund|purchase), refId, balanceAfter`
- feedback：`type(suggestion|bug), content, images[], reply, replyAt, read`
- redeemCodes（管理端）：`code, points|vipDays, usedBy, usedAt, expireAt`

### 4.10 clothesEmbeddings（可选）
`clothesId, model, dim, vector(base64 float16)`。用于去重、相似推荐、搭配兼容度。

关系图：users 1—N clothes / outfits / calendarEntries / trips；outfits N—N clothes（items 内嵌）；trips 1—N tripItems N—1 clothes；clothes N—1 categories / brands / storageLocations；clothes N—N tags。

---

## 5. 接口设计建议（我们自己的后端）

原 App 是 REST 风格（资源名 + 子动作），例如衣物、穿搭、标签、场合、收纳位置、品牌、日历、行程、AI 试衣（upload/generate/status/history）、图片注册与向量批量上传、增量同步（按 lastSyncTime）、天气、积分、会员、兑换码、反馈、弹窗、埋点批量上报、版本检查。下面按 **微信云开发云函数** 重新设计（每个云函数用 `action` 路由），自建服务器时可一一映射为 REST。

| 云函数 | action | 入参要点 | 说明 |
|---|---|---|---|
| `user` | login / getProfile / updateSettings / bindPhone / deleteAccount | | login 返回 openid 与初始化数据；deleteAccount 级联删除 |
| `clothes` | list / get / create / update / remove / batchCreate / reorder / batchUpdate | 分页 `cursor,limit`；筛选对象 | remove 时清理关联 |
| `outfits` | list / get / create / update / remove / addPhoto | | |
| `dict` | list / create / update / remove / reorder | `type: category|tag|outfitTag|occasion|brand|storage` | 通用字典 |
| `vision` | cutout / analyze / analyzeScreenshot | `fileID` | 抠图、打标、订单截图解析（调第三方，见 §6） |
| `weather` | current / forecast | `lat,lng` 或 `city` | 服务端缓存 1h |
| `recommend` | daily / byAnchor / batch / tripPack | `date, weather, occasionId?, anchorClothesId?` | §6.3 算法 |
| `calendar` | month / day / upsert / remove | | 维护 wearCount |
| `trips` | list / get / create / update / remove / setItem / autoFill | | |
| `tryon` | uploadModel / submit / status / history / cancel | | 扣积分 + 异步任务 + 订阅消息 |
| `points` | balance / ledger / redeem | | 事务 |
| `vip` | status / backupInfo | | 首版可不做 |
| `feedback` | submit / list / markRead | | |
| `stats` | overview / wear / distribution | | 聚合查询 |

约定：统一返回 `{code: 0, data, msg}`；错误码分段（1xxx 参数、2xxx 权限、3xxx 业务如积分不足、5xxx 第三方失败）；列表统一游标分页；所有写操作服务端校验 `_openid`。

---

## 6. AI / 图像能力与可商用替代

### 6.1 抠图（去背景）
原 App：端侧轻量显著性分割模型。小程序端侧跑大模型不现实，改服务端：
| 方案 | 说明 |
|---|---|
| 阿里云视觉智能开放平台「商品分割 / 通用分割」 | 国内、按量计费、可商用，首选 |
| 腾讯云「人像/商品分割」、百度 AI「图像主体分割」 | 同类备选 |
| 自部署开源：**BiRefNet**（MIT）、**RMBG**（注意 RMBG-1.4/2.0 的商用许可限制，需单独授权）、U²-Net（Apache-2.0） | 用云托管/GPU 实例跑，成本可控 |
输出：透明 PNG + 400px 缩略图存云存储。

### 6.2 自动打标（分类/颜色/材质/季节/保暖/版型/长度/层次/风格）
- **方案 A（推荐首版）**：多模态大模型 + JSON Schema 输出（如通义千问 VL、豆包视觉、GLM-4V 等国内可商用 API）。把 §4.2 的枚举作为允许值写进提示词，强制返回 JSON；颜色另用像素聚类（k-means on 非透明像素）得到 HEX，更稳定。
- **方案 B（降本/离线）**：自部署开源图文双塔模型（如 Chinese-CLIP（MIT）、SigLIP（Apache-2.0））做零样本分类：为每个维度准备中文/英文同义词提示词 → 预计算文本向量 → 图像向量余弦相似度取 Top1，并按维度设阈值，低于阈值留空让用户选。这正是原 App 的思路，但词表、提示词、阈值需我们自己编写和标定。
- 用户手改字段写入 `manualFields`，重新识别不覆盖。

### 6.3 自动搭配算法（我们自己设计的可实现版本）
1. **候选池**：status=active 且 inAutoOutfit=true；按用户设置排除分类/衣物；若"只用当季"则 seasons 含当前季节（无季节信息视为四季）。
2. **有效温度**：`eff = 当日均温 - 0.5×(风力等级>4) - 2×(下雨)`；按温度带确定需要的层次：
   - ≥26℃：base（短袖/薄）+ bottom（短/薄），禁 outer、禁 warm/very_warm
   - 18–26℃：base + bottom，outer 可选（薄外套）
   - 10–18℃：base/mid + bottom + outer(medium)
   - <10℃：base + mid + outer(warm/very_warm) + 长下装
   硬规则示例：夏季禁羽绒/大衣/手套；very_warm 上装与 very_warm 外套不同时出现（太热）。
3. **骨架**：`onepiece` 或 `top+bottom`，可选 `outer`、`shoes`、`bag/accessory`。
4. **打分**（0–100 加权）：温度契合 30、季节契合 15、颜色和谐 20（同色系/中性色+1 个强调色加分，>3 个高饱和色扣分）、风格一致 15（styles 交集）、场合匹配 10、轮换新鲜度 10（lastWearDate 越久越高，7 天内穿过扣分）。有向量时加"兼容度"项（历史保存穿搭里共同出现的单品对加分）。
5. **多样性**：一批内同一件单品最多出现 2 次；贪心选取 + 去重（同单品集合视为同一套）。
6. **锚点模式**：固定某件衣物，其余槽位按上述打分补全。
7. **装箱模式**：天数 × 每日骨架，单品可复用（上装 2 天/件、下装 3 天/件、外套全程 1–2 件），输出清单与每日计划。
返回每套的 `score` 与 `reasons[]`（如"适合 22℃""配色：同色系"），用于前端展示推荐理由。

### 6.4 AI 试衣
- 国内可商用 API：阿里云百炼「AI 试衣」（OutfitAnyone 系列）、其他云厂商虚拟试衣接口；或自部署开源虚拟试衣模型（如 IDM-VTON、CatVTON、OOTDiffusion——**务必逐一核对许可证，部分为非商用许可**）。
- 流程：云函数校验积分 → 事务扣积分写 ledger → 写 tryonJobs(pending) → 调第三方异步接口 → 定时触发器/回调更新状态 → 成功后加可见"AI 生成"水印 + 元数据标识，发订阅消息；失败自动退积分。
- 内容安全：模特图上传前走 `security.imgSecCheck`/内容安全接口；只允许本人照片，协议中写明。

### 6.5 天气
和风天气（QWeather）、心知天气等商用 API；云函数缓存 1 小时，按经纬度取 0.1° 网格做缓存键。

### 6.6 订单截图解析
多模态大模型返回 `[{bbox, title, price, color, size}]`，按 bbox 裁剪商品图后走 §6.1/6.2。

---

## 7. 微信小程序落地注意事项（原生 + 云开发）

1. **包体**：主包 ≤2MB，总包 ≤20MB（分包）。建议分包：`pkg-wardrobe`（添加/批量/详情）、`pkg-outfit`（穿搭/拼图）、`pkg-tools`（日历/行程/统计）、`pkg-ai`（试衣）。图标用 iconfont 或小体积 SVG，自绘，勿用原 App 素材。
2. **登录**：`wx.login` + 云函数取 openid 即可；手机号用 `<button open-type="getPhoneNumber">`（需企业主体、付费）。QQ/Apple/一键登录在小程序不适用。
3. **隐私合规**：小程序隐私保护指引里声明 相册、摄像头、位置（`wx.getFuzzyLocation` 足够天气用，比精确定位好过审）；首次使用前弹自定义隐私授权（`wx.onNeedPrivacyAuthorization`）。
4. **图片**：`wx.chooseMedia`（count≤9 每次，批量需多次）→ `wx.compressImage` → `wx.cloud.uploadFile`；列表用缩略图 + `lazy-load`；透明 PNG 用 `<image mode="aspectFit">`。
5. **拼图**：Canvas 2D（`type="2d"`）实现拖拽缩放旋转；导出 `wx.canvasToTempFilePath` → `wx.saveImageToPhotosAlbum`（需相册写入授权）。
6. **滑动卡片**：`movable-view` 或手写 touch 手势 + CSS transform；注意 60fps，用 WXS 响应事件。
7. **日历**：自绘月视图组件（7×6 网格），按月批量拉 calendarEntries。
8. **图表**：ec-canvas（ECharts 小程序版）或自绘 Canvas。
9. **长任务**：AI 试衣用订阅消息（`wx.requestSubscribeMessage`）通知结果；云函数默认超时 3s，可调至 60s，第三方异步任务用定时触发器轮询。
10. **数据库安全规则**：所有集合 `"read": "doc._openid == auth.openid", "write": "doc._openid == auth.openid"`；积分、会员、tryonJobs、redeemCodes 客户端只读或不可访问，仅云函数写。
11. **离线与同步**：小程序本地存储 10MB 上限，只缓存衣物列表元数据 + 缩略图路径；写操作失败放入本地队列，下次启动重放（原 App 也有上传队列与重试上限）。
12. **支付/虚拟商品**：iOS 小程序禁止虚拟支付，积分/会员需注意平台规则（可只在安卓开放，或采用激励视频/兑换码获取积分）。
13. **AIGC 合规**：生成内容显式+隐式标识；如对公众提供生成式 AI 服务，评估算法备案/大模型备案要求，优先用已备案的第三方模型 API。
14. **电商导购**：跳转淘宝需走淘宝联盟官方小程序跳转/口令方案，首版建议不做。

---

## 8. 复刻优先级建议

- **MVP（2–3 周）**：登录、衣橱 CRUD + 单张添加（抠图+大模型打标）、分类/标签/场合/收纳位置管理、我的穿搭（选单品）、天气 + 今日推荐（规则算法）、穿搭日历。
- **V1**：批量添加、统计、出行装箱、拼图、刷搭配、自动搭配过滤设置、反馈。
- **V2**：AI 试衣 + 积分、订单截图导入、向量去重/相似推荐、云备份导出、素材库。

---

## 9. 可直接粘贴给编码 agent 的任务提示词

```
你是资深微信小程序工程师。请用「原生微信小程序 + 微信云开发」从零实现一款个人电子衣橱与智能穿搭小程序（暂名：衣橱助手）。这是独立原创实现：自行设计 UI、文案、图标与代码，不得使用任何第三方 App 的源码、图片或素材。

【规格来源】严格以随附文档《z衣橱拆解与复刻规格》为准：§2 页面与行为规格、§3 用户流程、§4 数据模型、§5 云函数接口、§6 AI 能力与自动搭配算法、§7 小程序注意事项。文档未写明的细节由你做合理决定，并在 README 的"设计决策"一节记录。

【技术约束】
- 原生小程序（WXML/WXSS/JS，可用 TypeScript），基础库 ≥3.0；Canvas 2D；分包：主包只放 Tab 页（首页、衣橱、穿搭、我的）。
- 云开发：云函数按 §5 用 action 路由，统一返回 {code,data,msg}；数据库集合按 §4，附 database/indexes.json 与安全规则 database/rules.json（积分、会员、tryonJobs 仅云函数可写）。
- AI 能力全部封装在 cloudfunctions/vision 与 cloudfunctions/tryon 内的 provider 适配层，默认实现：抠图=阿里云视觉智能商品分割，打标=国内多模态大模型 API（JSON Schema 输出，允许值取自 §4.2 枚举），颜色=服务端像素 k-means；天气=和风天气。所有密钥只从云函数环境变量读取，代码与仓库中不得出现真实密钥。
- 自动搭配按 §6.3 在 cloudfunctions/recommend 中实现为纯函数模块，并写单元测试（温度带、硬规则、多样性、锚点模式、装箱模式各至少 2 个用例）。

【交付顺序】
1. 项目骨架、app.json 路由与分包、全局样式变量、请求封装（callFunction + 错误码处理 + 本地失败重试队列）。
2. MVP：登录与隐私授权 → 字典管理（分类两级/标签/场合/品牌/收纳位置）→ 衣物添加/编辑/详情/列表筛选排序 → 穿搭新建/列表/详情 → 天气 + 今日推荐 + "今天穿这套" → 穿搭日历（维护 wearCount/lastWearDate）。
3. V1：批量添加（两步确认与成功/失败汇总）、统计页、出行装箱（智能补全 + 勾选进度）、拼图（拖拽缩放旋转 + 背景 + 导出）、刷搭配卡片、自动搭配过滤设置、反馈。
4. V2：AI 试衣（模特图、扣积分事务、异步任务、订阅消息、失败退分、AI 生成标识水印）、订单截图导入。
每完成一个阶段：列出已实现页面、可演示步骤、已知问题。

【质量要求】
- 每个页面实现文档中的全部状态：加载中、空、错误可重试、数据不足提示。
- 删除字典项/衣物时级联清理引用，并在删除前提示影响范围。
- 用户手动修改过的识别字段记录到 manualFields，重新识别时不覆盖。
- 列表分页（游标），图片走缩略图 + 懒加载；主包体积 < 1.5MB。
- 输出完整可运行项目目录（miniprogram/、cloudfunctions/、database/、README.md），README 写清环境变量、部署云函数与初始化系统分类数据的步骤。
```
