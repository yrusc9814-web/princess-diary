import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db.dart';
import 'images.dart';
import 'settings.dart';

/// 备份包 .wrdx = zip（data.json 数据库导出 + images/ 全部图片）。
/// 导入兼容 1.0 版导出的 .zip（data.json version 1）。
class Backup {
  /// 备份文件名：`gongzhuriji_yyyy-MM-dd_HHmm.wrdx`，例 `gongzhuriji_2026-11-16_0300.wrdx`。
  /// [time] 默认当前时间，测试可注入。
  static String fileNameFor(DateTime time) =>
      '$autoBackupPrefix${DateFormat('yyyy-MM-dd_HHmm').format(time)}$autoBackupSuffix';

  /// 自动备份文件名前缀 / 后缀，也用于在公共目录里查找旧文件。
  static const autoBackupPrefix = 'gongzhuriji_';
  static const autoBackupSuffix = '.wrdx';

  /// 手动「导出备份包」：在临时目录生成 .wrdx（同样用新命名），交给页面分享。
  static Future<File> export() async {
    final out = File(p.join((await getTemporaryDirectory()).path, fileNameFor(DateTime.now())));
    await writeArchive(out, await AppDb.I.exportTables());
    Settings.lastExport = DateTime.now().millisecondsSinceEpoch;
    return out;
  }

  /// 把导出表 JSON + ImageStore 里的全部图片写成一个 .wrdx。[out] 若已存在会先删掉。
  static Future<void> writeArchive(File out, Map<String, Object> tables) async {
    if (await out.exists()) await out.delete();
    final json = File(p.join(out.parent.path, 'data_${DateTime.now().microsecondsSinceEpoch}.json'));
    await json.writeAsString(jsonEncode(tables));
    final enc = ZipFileEncoder();
    try {
      enc.create(out.path);
      await enc.addFile(json, 'data.json');
      final dir = Directory(ImageStore.root);
      if (await dir.exists()) {
        await for (final f in dir.list()) {
          if (f is File) await enc.addFile(f, 'images/${p.basename(f.path)}');
        }
      }
      await enc.close();
    } finally {
      try {
        if (await json.exists()) await json.delete();
      } catch (_) {}
    }
  }

  /// 返回导入的衣物数
  static Future<int> import(String path) async {
    final tmp = await getTemporaryDirectory();
    final dest = Directory(p.join(tmp.path, 'import_${DateTime.now().millisecondsSinceEpoch}'));
    await dest.create(recursive: true);
    try {
      final input = InputFileStream(path);
      final archive = ZipDecoder().decodeBuffer(input);
      await extractArchiveToDisk(archive, dest.path);
      await input.close();
      final jf = File(p.join(dest.path, 'data.json'));
      if (!await jf.exists()) throw const FormatException('不是有效的备份包');
      final data = jsonDecode(await jf.readAsString()) as Map<String, dynamic>;
      // 2.0 包带 schema=2；1.0 旧 zip 没有固定版本字段，只要有 clothes 表就按旧格式转换
      if (data['schema'] != 2 && data['clothes'] is! List) throw const FormatException('不是有效的备份包');
      // 图片：1.0 旧包图片目录名不固定，递归收集除 data.json 外的全部文件
      await Directory(ImageStore.root).create(recursive: true);
      await for (final f in dest.list(recursive: true)) {
        if (f is File && p.basename(f.path) != 'data.json') {
          await f.copy(p.join(ImageStore.root, p.basename(f.path)));
        }
      }
      await AppDb.I.importTables(data);
      return ((data['clothes'] as List?) ?? []).length;
    } finally {
      try {
        await dest.delete(recursive: true);
      } catch (_) {}
    }
  }
}
