# 2.1.3 扫描图片修复 — 无头浏览器测试结果（2026-10-30 CST）
环境：Debian chromium (apt) + Python Playwright，UA = App 的 Android Chrome UA，412x915 @2.625x，经 127.0.0.1:3128 代理（出口在海外）。
页面加载后注入 observer.js（模拟 onPageFinished），等待 6–8s，再分别执行 scan_old.js / scan_new.js。

## A. 测试商品 1048161815972（e.tb.cn/h.jUUOWu0）— 无法拿到真实商品页
h5.m.taobao.com / item.taobao.com / e.tb.cn → m.intl.taobao.com；main.m.taobao.com 与 pages-g.m.taobao.com/wow/z/app/detail-next/item/index?id=… 
都被 mtop.taobao.detail.data.get 返回 RGV587_ERROR(被挤爆啦) 并跳 login.m.taobao.com（bizEntrance=taobao_h5_oversea），只有登录页。
在该页（main.m.taobao.com/detail/index.html?id=1048161815972）：
- OLD: https://gw.alicdn.com/tfs/TB1QZN.CYj1gK0jSZFuXXcrHpXa-200-200.png（关闭×图标）
- NEW: []（→ 弹兜底对话框）
截图 shot_tb_detail.png

## B. 真实淘宝商品页（海外版 SSR，MUJI 手机壳，带淘 logo 横幅）
https://www.taobao.com/list/item/NXI1VCtmVlVuMHA3dG5BTkNMa1NRZz09.htm
主图是 412x412 的 <img src="data:image/jpg;base64,…">（服务端内联 WebP 468x468）；所有带 URL 的 <img> 都是 -tps- UI 素材。
- OLD: []（0 张）
- NEW: 1) data:image 内联主图（解码为 tb_list_inline_main.jpg） 2) https://img.alicdn.com/imgextra/i3/3189900846/O1CN01izYShp1I7WBSVtWLw_!!3189900846.jpg（同一主图原图，来自 HTML 文本） 3) …O1CN01WoLHpJ1I7WB8v9fo4_!!3189900846.png（80x80 店铺头像 → App 选图页按真实尺寸 <160 自动隐藏）
截图 shot_tb_list.png / shot_tb_list_full.png

## C. 本地 fixture（模拟新版 H5：太好逛了吧/打开淘宝 横幅 + 淘 logo、样式表 CSS 背景主图、_80x80 缩略图、TV 素材、canvas、shadow DOM、内联 JSON）
- OLD: 淘 logo (O1CN01GXym4K1qcq5dHLTgQ_!!6000000005517-2-tps-268-268.png)、TV 素材 (…-tps-222-222.png)、推荐图 _220x220 —— 复现 bug：主图缺失、logo 入选
- NEW: 主图(CSS 背景，去缩略后缀)、shadow DOM 图、推荐图(原图)、canvas 源图、内联 JSON 的 bao/uploaded 图；logo/TV/× 全部被滤掉，缩略图与主图去重为 1 张
截图 shot_fixture.png

关键发现：淘 logo 并不是 /tfs/ 路径，而是 img.alicdn.com/imgextra/…O1CN…!!6000000005517-2-tps-268-268.png —— 也在 imgextra/O1CN 下。
区分依据是 “-tps-W-H” 后缀和 “!!6000000…” 设计平台账号；商品图是 “!!<卖家ID>.jpg” 或 bao/uploaded/…item_pic。
