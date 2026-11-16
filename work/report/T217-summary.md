# T217 总结：每天凌晨 3 点自动备份 + 备份文件改名

## 结论

- 功能已按需求完成：WorkManager 每日 03:00 周期任务（App 未打开也跑）+ 启动兜底补跑；数据指纹相同则跳过不写文件，有变化才写新包并删旧包；文件名统一为 `gongzhuriji_yyyy-MM-dd_HHmm.wrdx`（手动导出同样改名）。
- `flutter test` 全量：**61 通过 / 1 失败**，唯一失败是原有的 `test/screens_test.dart` 缺字体（`/tmp/shot_fonts/NotoSansSC-Regular.otf` 不存在），按要求未处理，无新增失败。
- `flutter analyze`：**27 条 info，0 warning / 0 error**，与基线一致，新代码未新增任何 info。
- 未改 `pubspec.yaml` 的 `version` 行（仍是 2.1.4+7），未 commit / checkout / stash，未打包 APK。

## 改了什么

### 新增 `lib/services/auto_backup.dart`（358 行）

- `ImageStamp`：图片文件名 + 大小 + 修改时间。
- `AutoBackupStore` 接口：`hash / backupAt / file / lastCheck / error / enabled`，两套实现——`SettingsAutoBackupStore`（SharedPreferences）与 `MemoryAutoBackupStore`（测试）。
- `BackupTarget` 接口：`list()` / `put()` / `delete()`；正式实现 `ChannelBackupTarget` 走 `MethodChannel('princess_diary/backup')`，测试用内存实现。
- `AutoBackup.fingerprint()`：`exportTables()` 的 JSON 去掉每次都变的 `exportedAt`，键排序，再拼上按文件名排序的「文件名|大小|修改时间」，算 sha256（64 位十六进制）。图片顺序不影响结果。
- `AutoBackup.untilNextRun()`：算到下一个本地 03:00 的时长；正好 03:00 返回 24h。
- `AutoBackup.shouldRunOnLaunch()`：从未检查或距上次检查 ≥ 24h 返回 true。
- `AutoBackup.run()`：算指纹 → 相同则只更新 `lastCheck` 并返回 `skipped` → 不同则写临时文件、`put` 进公共目录、成功后再删掉目录里其它 `gongzhuriji_*.wrdx`、最后更新 hash/backupAt/file/lastCheck。写文件或拷贝失败时删临时文件、**不更新指纹与备份时间**、记录 `error`，旧文件原样保留。
- `AutoBackupService`：`initBackground()`（`DartPluginRegistrant.ensureInitialized()` + `Settings.init()` + `ImageStore.init()` + `AppDb.I.open()`）、`schedule()`（`registerPeriodicTask`，24h 周期，首次延迟到下一个 03:00，`ExistingPeriodicWorkPolicy.keep`，约束不要求联网/充电）、`cancel()`、`syncSchedule()`、`maybeRunOnLaunch()`（后台 isolate 之外用 `unawaited` 跑，不阻塞首屏，进程内只跑一次）。
- `autoBackupCallbackDispatcher()`（`@pragma('vm:entry-point')`）+ `WorkmanagerController` 薄封装。

### `lib/services/backup.dart`

- 新增 `Backup.fileNameFor(DateTime)` 与常量 `autoBackupPrefix = 'gongzhuriji_'`、`autoBackupSuffix = '.wrdx'`。
- `Backup.export()` 改用新命名（原 `WardrobeExport_` 命名去掉）。
- `writeArchive()` 保持 zip 结构 `data.json` + `images/`，先删同名输出文件再写。

### `lib/services/settings.dart`

新增自动备份设置项：`autoBackupEnabled`（默认 true）、`autoBackupHash`、`autoBackupAt`、`autoBackupFile`、`autoBackupLastCheck`、`autoBackupError`。

### `lib/pages/backup_page.dart`

新增「自动备份」卡片：开关（关闭即取消 WorkManager 任务）、上次自动备份时间与文件名、上次检查时间、无变化时的「数据无变化，已跳过」提示、失败原因、说明文案「每天凌晨 3 点自动备份到 文档/公主日记备份，只保留最新一份；手机省电可能让时间稍晚」，以及「立即检查并备份」按钮（手动触发完整流程，便于验证）。沿用粉色主题常量（`kRose`、`kPinkBorder`、`kCardShadow` 等）。

### `lib/main.dart`

启动时在 `runApp` 前 `unawaited` 注册/同步定时任务并触发兜底补跑，`catchError` 兜住异常，不影响启动。

### `android/.../MainActivity.kt`

新增 `princess_diary/backup` MethodChannel：

- `listBackups` / `saveBackup` / `deleteBackup`。
- Android 10+ 用 `MediaStore.Downloads`，`RELATIVE_PATH = Documents/公主日记备份`，`IS_PENDING` 写完置 0，同名先删保证只留一份；Android 9 及以下直接写公共 `Documents/公主日记备份`，运行时申请 `WRITE_EXTERNAL_STORAGE`（requestCode 21701）。

### `AndroidManifest.xml`

新增 `WRITE_EXTERNAL_STORAGE`（`android:maxSdkVersion="28"`），Android 10+ 不需要。

### `pubspec.yaml` / `pubspec.lock`

新增依赖 `workmanager: ^0.10.10`、`crypto: ^3.0.8`（任务允许的两个包），未改 `version:` 行。

### 新增测试 `test/t217_auto_backup_test.dart`（23 例）

文件名格式（含前后缀常量）、指纹（不变/改数据/增删图/大小与 mtime 变化/图片顺序无关）、备份流程（首次写、相同跳过、有变化写新删旧、加图算变化、写失败保留旧文件不更新指纹、拷贝失败同样、其它前缀文件不动）、打包格式（`data.json` + `images/`，新命名）、下一个 03:00 延迟（00:12→2h48m、03:00→24h、23:59→3h01m、跨月跨年）、启动兜底阈值（0/23h/25h/正好 24h）。

## 测试结果

- `flutter test`（`source/wardrobe-android`，`NO_PROXY=127.0.0.1,localhost`）：**61 通过 / 1 失败**，日志见 `work/report/T217-test.txt`。
  - 失败项：`test/screens_test.dart: (setUpAll)` —— `PathNotFoundException: /tmp/shot_fonts/NotoSansSC-Regular.otf`，原有缺字体问题，未改。
  - T217 新增 23 例全部通过；T214–T216 及其它原有测试全部通过。
- `flutter analyze`：27 条 info（`work/report/T217-analyze-after.txt`），0 warning / 0 error，与基线 27 条一致。

## 手机上怎么验证

1. 安装新包后打开 App，进入「我的 → 数据迁移与备份」，能看到「自动备份」卡片，开关默认开。
2. 手动触发：点卡片右下角 **「立即检查并备份」**。首次应提示「已备份：gongzhuriji_2026-xx-xx_HHmm.wrdx」；不做任何改动再点一次，应提示「数据无变化，已跳过」，且目录里文件数量不变。
3. 找文件：系统「文件管理 / 文档」→ `Documents/公主日记备份/`（部分机型显示为「文档/公主日记备份」）。目录内应只有一个 `gongzhuriji_*.wrdx`；手动「导出备份包」生成的文件也是同样命名。
4. 后台定时：可把手机时间调到 02:5x 并保持后台，等 03:00 后看卡片「上次自动备份」是否更新；或用 adb 强制触发：
   `adb shell cmd jobscheduler run -f com.mywardrobe.my_wardrobe <jobId>`（jobId 可用 `adb shell dumpsys jobscheduler | grep my_wardrobe` 查）。
5. 覆盖验证：加一件衣物后点「立即检查并备份」，目录里旧文件应被新文件替换（仍只有一份）。
6. 关闭开关后再点，应不再产生新文件；重新打开会重新注册任务。

## 备注 / 已知限制

- WorkManager 周期任务受系统省电策略影响，实际执行时间可能晚于 03:00（说明文案已注明）。
- Android 9 及以下首次备份会弹一次存储权限；拒绝则备份失败并在卡片显示原因，旧文件不受影响。
- `pubspec.lock` 的变化来自新增两个依赖，属允许范围。
- 2026-11-15 修正（T217 小修）：Android 10+ 的 `list/save/delete` 三处 MediaStore 入口由 `MediaStore.Downloads.EXTERNAL_CONTENT_URI` 统一改为 `MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)`（Downloads 集合只允许 `Download/` 子目录，写 `RELATIVE_PATH=Documents/公主日记备份` 会被系统拒绝），类注释同步更新；`work/report/T217-diff.patch` 已重新生成。
