import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../data/db.dart';
import 'backup.dart';
import 'images.dart';
import 'settings.dart';

/// 图片目录里一个文件的名字 + 大小 + 修改时间，用于算数据指纹。
@immutable
class ImageStamp {
  const ImageStamp(this.name, this.size, this.mtimeMs);
  final String name;
  final int size;
  final int mtimeMs;

  @override
  String toString() => '$name|$size|$mtimeMs';
}

/// 自动备份用到的设置项读写。抽成接口便于测试注入内存实现。
abstract class AutoBackupStore {
  String get hash;
  set hash(String v);
  int get backupAt;
  set backupAt(int v);
  String get file;
  set file(String v);
  int get lastCheck;
  set lastCheck(int v);
  String get error;
  set error(String v);
  bool get enabled;
  set enabled(bool v);
}

/// 正式实现：存进 SharedPreferences。
class SettingsAutoBackupStore implements AutoBackupStore {
  const SettingsAutoBackupStore();
  @override
  String get hash => Settings.autoBackupHash;
  @override
  set hash(String v) => Settings.autoBackupHash = v;
  @override
  int get backupAt => Settings.autoBackupAt;
  @override
  set backupAt(int v) => Settings.autoBackupAt = v;
  @override
  String get file => Settings.autoBackupFile;
  @override
  set file(String v) => Settings.autoBackupFile = v;
  @override
  int get lastCheck => Settings.autoBackupLastCheck;
  @override
  set lastCheck(int v) => Settings.autoBackupLastCheck = v;
  @override
  String get error => Settings.autoBackupError;
  @override
  set error(String v) => Settings.autoBackupError = v;
  @override
  bool get enabled => Settings.autoBackupEnabled;
  @override
  set enabled(bool v) => Settings.autoBackupEnabled = v;
}

/// 内存实现（测试用）。
class MemoryAutoBackupStore implements AutoBackupStore {
  MemoryAutoBackupStore({
    this.hash = '',
    this.backupAt = 0,
    this.file = '',
    this.lastCheck = 0,
    this.error = '',
    this.enabled = true,
  });

  @override
  String hash;
  @override
  int backupAt;
  @override
  String file;
  @override
  int lastCheck;
  @override
  String error;
  @override
  bool enabled;
}

/// 备份文件的最终去处：手机公共目录 `Documents/公主日记备份/`。
abstract class BackupTarget {
  /// 目录里已有的 `gongzhuriji_*.wrdx` 文件名。
  Future<List<String>> list();

  /// 把本地文件放进去，返回写入后的实际文件名（MediaStore 可能重名加后缀）。
  Future<String> put(File local, String fileName);

  /// 按文件名删除。
  Future<void> delete(String fileName);
}

/// 通过 MethodChannel 交给原生写入 MediaStore（Android 10+）或公共目录（Android 9-）。
class ChannelBackupTarget implements BackupTarget {
  static const channel = MethodChannel('princess_diary/backup');
  const ChannelBackupTarget();

  @override
  Future<List<String>> list() async {
    final r = await channel.invokeListMethod<String>('listBackups');
    return r ?? const [];
  }

  @override
  Future<String> put(File local, String fileName) async {
    final r = await channel.invokeMethod<String>('saveBackup', {'path': local.path, 'name': fileName});
    if (r == null || r.isEmpty) throw StateError('保存备份失败');
    return r;
  }

  @override
  Future<void> delete(String fileName) => channel.invokeMethod<void>('deleteBackup', {'name': fileName});
}

/// 一次自动备份的结果。
class AutoBackupResult {
  const AutoBackupResult({required this.ok, required this.skipped, this.fileName, this.error});
  final bool ok;
  final bool skipped;
  final String? fileName;
  final String? error;

  @override
  String toString() => 'AutoBackupResult(ok: $ok, skipped: $skipped, file: $fileName, error: $error)';
}

/// 每天 03:00 自动备份：算指纹 → 相同跳过 → 不同则写新文件、删旧文件。
class AutoBackup {
  AutoBackup({
    AutoBackupStore? store,
    BackupTarget? target,
    Future<Map<String, Object>> Function()? readTables,
    Future<List<ImageStamp>> Function()? readImages,
    Future<void> Function(File out, Map<String, Object> tables)? writeArchive,
    Future<Directory> Function()? tempDir,
    DateTime Function()? now,
  })  : store = store ?? const SettingsAutoBackupStore(),
        target = target ?? const ChannelBackupTarget(),
        _readTables = readTables ?? (() => AppDb.I.exportTables()),
        _readImages = readImages ?? _listImageDir,
        _writeArchive = writeArchive ?? Backup.writeArchive,
        _tempDir = tempDir ?? getTemporaryDirectory,
        _now = now ?? DateTime.now;

  final AutoBackupStore store;
  final BackupTarget target;
  final Future<Map<String, Object>> Function() _readTables;
  final Future<List<ImageStamp>> Function() _readImages;
  final Future<void> Function(File out, Map<String, Object> tables) _writeArchive;
  final Future<Directory> Function() _tempDir;
  final DateTime Function() _now;

  static Future<List<ImageStamp>> _listImageDir() async {
    final dir = Directory(ImageStore.root);
    final out = <ImageStamp>[];
    if (!await dir.exists()) return out;
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final st = await f.stat();
      out.add(ImageStamp(p.basename(f.path), st.size, st.modified.millisecondsSinceEpoch));
    }
    return out;
  }

  /// 数据指纹：exportTables() 的 JSON（去掉每次都会变的 exportedAt）+ 图片目录每个文件的
  /// 文件名/大小/修改时间，按名称排序后算 sha256。
  static String fingerprint(Map<String, Object> tables, List<ImageStamp> images) {
    final sorted = <String, Object>{};
    for (final k in tables.keys.toList()..sort()) {
      if (k == 'exportedAt') continue;
      sorted[k] = tables[k]!;
    }
    final imgs = [...images]..sort((a, b) => a.name.compareTo(b.name));
    final b = StringBuffer(jsonEncode(sorted));
    for (final i in imgs) {
      b.write('\n${i.name}|${i.size}|${i.mtimeMs}');
    }
    return sha256.convert(utf8.encode(b.toString())).toString();
  }

  /// 下一个本地 03:00 距 [now] 的时长。正好 03:00 整返回 24 小时。
  static Duration untilNextRun(DateTime now) {
    var next = DateTime(now.year, now.month, now.day, 3);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next.difference(now);
  }

  /// 是否该在启动时补跑：距上次检查超过 24 小时。
  static bool shouldRunOnLaunch(int lastCheckMs, DateTime now) =>
      lastCheckMs <= 0 || now.millisecondsSinceEpoch - lastCheckMs >= const Duration(hours: 24).inMilliseconds;

  Future<AutoBackupResult> run() async {
    final now = _now();
    final tables = await _readTables();
    final images = await _readImages();
    final fp = fingerprint(tables, images);

    // 和上次自动备份比：数据完全一样只更新检查时间，不写文件。
    if (fp == store.hash && store.hash.isNotEmpty) {
      store.lastCheck = now.millisecondsSinceEpoch;
      return const AutoBackupResult(ok: true, skipped: true);
    }

    final name = Backup.fileNameFor(now);
    final tmp = File(p.join((await _tempDir()).path, name));
    String written;
    try {
      await _writeArchive(tmp, tables);
      written = await target.put(tmp, name);
    } catch (e) {
      // 写失败：旧文件保留、指纹不动，只记下错误。
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      // 失败不更新指纹、也不更新检查时间，下次启动还会重试。
      store.error = '$e';
      return AutoBackupResult(ok: false, skipped: false, error: '$e');
    } finally {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }

    // 新文件已经写好，再删掉除最新一份以外的所有旧备份。
    try {
      for (final old in await target.list()) {
        if (old == written) continue;
        if (!old.startsWith(Backup.autoBackupPrefix)) continue;
        try {
          await target.delete(old);
        } catch (_) {}
      }
      store.hash = fp;
      store.backupAt = now.millisecondsSinceEpoch;
      store.file = written;
      store.lastCheck = now.millisecondsSinceEpoch;
      store.error = '';
      return AutoBackupResult(ok: true, skipped: false, fileName: written);
    } catch (e) {
      store.error = '$e';
      store.lastCheck = now.millisecondsSinceEpoch;
      return AutoBackupResult(ok: false, skipped: false, fileName: written, error: '$e');
    }
  }
}

/// 后台 isolate 的工作入口 + 兜底逻辑。
class AutoBackupService {
  AutoBackupService._();

  static const taskName = 'princessDiaryAutoBackup';
  static const uniqueName = 'com.mywardrobe.my_wardrobe.autoBackup';

  /// 在后台 isolate 里把插件 + sqflite / ImageStore / Settings 都初始化好。
  static Future<void> initBackground() async {
    // 后台 isolate 不会自动跑 Dart 侧的插件注册，必须先初始化，否则
    // path_provider / shared_preferences / sqflite 的通道拿不到实现。
    DartPluginRegistrant.ensureInitialized();
    await Settings.init();
    await ImageStore.init();
    await AppDb.I.open();
  }

  /// 注册每天一次的周期任务：首次延迟到下一个本地 03:00，之后每 24 小时一次。
  /// 约束不要求联网/充电，省电模式下系统可能推迟。
  static Future<void> schedule({DateTime? now}) async {
    final delay = AutoBackup.untilNextRun(now ?? DateTime.now());
    await Workmanager().initialize(autoBackupCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: const Duration(hours: 24),
      initialDelay: delay,
      // keep：已经注册过的任务不重建，避免每次启动都把 03:00 的计时往后推
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.notRequired, requiresCharging: false, requiresBatteryNotLow: false),
    );
  }

  /// 关掉开关时取消任务。
  static Future<void> cancel() async {
    await Workmanager().initialize(autoBackupCallbackDispatcher);
    await Workmanager().cancelByUniqueName(uniqueName);
  }

  /// 按当前开关状态注册或取消（启动时调用，开关默认开）。
  static Future<void> syncSchedule() async {
    if (Settings.autoBackupEnabled) {
      await schedule();
    } else {
      await cancel();
    }
  }

  static bool _launchedThisProcess = false;

  /// 打开 App 时调用：开关开着且距上次检查超过 24 小时，就在后台补跑一次，不阻塞界面。
  static Future<void> maybeRunOnLaunch() async {
    if (!Settings.autoBackupEnabled) return;
    if (_launchedThisProcess) return;
    if (!AutoBackup.shouldRunOnLaunch(Settings.autoBackupLastCheck, DateTime.now())) return;
    _launchedThisProcess = true;
    unawaited(Future(() async {
      try {
        final r = await AutoBackup().run();
        debugPrint('auto backup on launch: $r');
      } catch (e) {
        Settings.autoBackupError = '$e';
        debugPrint('auto backup on launch failed: $e');
      }
    }));
  }
}

/// WorkManager 后台任务入口（顶层函数，必须带 vm:entry-point）。
@pragma('vm:entry-point')
void autoBackupCallbackDispatcher() {
  WorkmanagerController.execute();
}

/// 对 workmanager 的薄封装，方便单测时替换。
class WorkmanagerController {
  WorkmanagerController._();
  static Future<void> execute() async {
    Workmanager().executeTask((task, inputData) async {
      try {
        await AutoBackupService.initBackground();
        if (!Settings.autoBackupEnabled) return true;
        final r = await AutoBackup().run();
        debugPrint('auto backup task: $r');
        return r.ok;
      } catch (e) {
        Settings.autoBackupError = '$e';
        debugPrint('auto backup task failed: $e');
        return false;
      }
    });
  }
}
