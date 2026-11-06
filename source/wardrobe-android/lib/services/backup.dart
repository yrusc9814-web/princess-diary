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
  static Future<File> export() async {
    final tmp = await getTemporaryDirectory();
    final name = 'WardrobeExport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.wrdx';
    final out = File(p.join(tmp.path, name));
    if (await out.exists()) await out.delete();
    final json = File(p.join(tmp.path, 'data.json'));
    await json.writeAsString(jsonEncode(await AppDb.I.exportTables()));
    final enc = ZipFileEncoder();
    enc.create(out.path);
    await enc.addFile(json, 'data.json');
    final dir = Directory(ImageStore.root);
    if (await dir.exists()) {
      await for (final f in dir.list()) {
        if (f is File) await enc.addFile(f, 'images/${p.basename(f.path)}');
      }
    }
    await enc.close();
    await json.delete();
    Settings.lastExport = DateTime.now().millisecondsSinceEpoch;
    return out;
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
