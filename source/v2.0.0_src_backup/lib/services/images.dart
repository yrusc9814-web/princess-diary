import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 图片文件都放在应用私有目录 images/ 下，数据库只存相对路径，便于备份迁移。
class ImageStore {
  ImageStore._();
  static late String root;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    root = p.join(dir.path, 'images');
    await Directory(root).create(recursive: true);
  }

  static String abs(String rel) => p.isAbsolute(rel) ? rel : p.join(root, rel);
  static File file(String rel) => File(abs(rel));

  static String _name(String prefix, String ext) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext';

  /// 原图：压到长边 1600，存 jpg
  static Future<String> saveOriginal(String srcPath) async {
    final bytes = await File(srcPath).readAsBytes();
    final jpg = await compute(_resizeJpg, (bytes, 1600));
    final rel = _name('orig', 'jpg');
    await file(rel).writeAsBytes(jpg);
    return rel;
  }

  static Future<String> savePng(Uint8List png, String prefix) async {
    final rel = _name(prefix, 'png');
    await file(rel).writeAsBytes(png);
    return rel;
  }

  /// 缩略图：长边 400，保留透明
  static Future<String> makeThumb(String rel) async {
    final bytes = await file(rel).readAsBytes();
    final png = await compute(_resizePng, (bytes, 400));
    return savePng(png, 'thumb');
  }

  static Future<String> saveBytes(Uint8List bytes, String prefix, String ext) async {
    final rel = _name(prefix, ext);
    await file(rel).writeAsBytes(bytes);
    return rel;
  }

  static Future<void> delete(String? rel) async {
    if (rel == null) return;
    final f = file(rel);
    if (await f.exists()) await f.delete();
  }
}

Uint8List _resizeJpg((Uint8List, int) a) {
  var im = img.decodeImage(a.$1)!;
  im = img.bakeOrientation(im);
  if (im.width > a.$2 || im.height > a.$2) {
    im = im.width >= im.height ? img.copyResize(im, width: a.$2) : img.copyResize(im, height: a.$2);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 88));
}

Uint8List _resizePng((Uint8List, int) a) {
  var im = img.decodeImage(a.$1)!;
  if (im.width > a.$2 || im.height > a.$2) {
    im = im.width >= im.height ? img.copyResize(im, width: a.$2) : img.copyResize(im, height: a.$2);
  }
  return Uint8List.fromList(img.encodePng(im));
}
