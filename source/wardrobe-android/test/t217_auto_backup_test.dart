import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wardrobe/services/images.dart';
import 'package:my_wardrobe/services/auto_backup.dart';
import 'package:my_wardrobe/services/backup.dart';
import 'package:path/path.dart' as p;

/// 内存里的备份目录，模拟 MediaStore / 公共目录。
class FakeTarget implements BackupTarget {
  FakeTarget([List<String>? initial]) : files = [...?initial];

  final List<String> files;
  bool failPut = false;
  int puts = 0;
  int deletes = 0;

  @override
  Future<List<String>> list() async => [...files];

  @override
  Future<String> put(File local, String fileName) async {
    puts++;
    if (failPut) throw const FileSystemException('磁盘已满');
    if (!local.existsSync()) throw const FileSystemException('临时文件不存在');
    files.add(fileName);
    return fileName;
  }

  @override
  Future<void> delete(String fileName) async {
    deletes++;
    files.remove(fileName);
  }
}

Map<String, Object> tables({String name = '白T', int count = 1}) => {
      'schema': 2,
      'app': 'my_wardrobe',
      // exportedAt 每次都变，但不能影响指纹
      'exportedAt': DateTime.now().toIso8601String(),
      'clothes': [
        for (var i = 0; i < count; i++) {'id': i + 1, 'name': name, 'price': 99.0},
      ],
      'outfits': <Object>[],
    };

List<ImageStamp> images({int extra = 0, int mtime = 1000}) => [
      const ImageStamp('orig_1.jpg', 100, 1000),
      const ImageStamp('thumb_1.png', 20, 1000),
      for (var i = 0; i < extra; i++) ImageStamp('orig_${i + 2}.jpg', 50, mtime + i),
    ];

AutoBackup build({
  required AutoBackupStore store,
  required BackupTarget target,
  Map<String, Object> Function()? data,
  List<ImageStamp> Function()? imgs,
  bool failWrite = false,
  DateTime? now,
}) {
  final dir = Directory.systemTemp.createTempSync('t217_');
  return AutoBackup(
    store: store,
    target: target,
    readTables: () async => (data ?? tables)(),
    readImages: () async => (imgs ?? images)(),
    writeArchive: (out, t) async {
      if (failWrite) throw const FileSystemException('没有空间');
      out.writeAsStringSync('fake archive ${t.length}');
    },
    tempDir: () async => dir,
    now: () => now ?? DateTime(2026, 11, 16, 3, 0),
  );
}

void main() {
  group('文件名格式', () {
    test('gongzhuriji_yyyy-MM-dd_HHmm.wrdx', () {
      expect(Backup.fileNameFor(DateTime(2026, 11, 16, 3, 0)), 'gongzhuriji_2026-11-16_0300.wrdx');
      expect(Backup.fileNameFor(DateTime(2026, 1, 2, 23, 59)), 'gongzhuriji_2026-01-02_2359.wrdx');
      expect(Backup.fileNameFor(DateTime(2026, 12, 31, 0, 5)), 'gongzhuriji_2026-12-31_0005.wrdx');
    });

    test('前缀/后缀与自动清理用的常量一致', () {
      final name = Backup.fileNameFor(DateTime(2026, 11, 16, 3, 0));
      expect(name.startsWith(Backup.autoBackupPrefix), isTrue);
      expect(name.endsWith(Backup.autoBackupSuffix), isTrue);
    });
  });

  group('数据指纹', () {
    test('数据不变，两次指纹相同（exportedAt 变化不影响）', () {
      final a = AutoBackup.fingerprint(tables(), images());
      final b = AutoBackup.fingerprint(tables(), images());
      expect(a, b);
      expect(a.length, 64);
    });

    test('图片顺序不影响指纹', () {
      final a = AutoBackup.fingerprint(tables(), images());
      final b = AutoBackup.fingerprint(tables(), images().reversed.toList());
      expect(a, b);
    });

    test('改一条数据后指纹不同', () {
      final a = AutoBackup.fingerprint(tables(), images());
      final b = AutoBackup.fingerprint(tables(name: '黑T'), images());
      expect(a, isNot(b));
      final c = AutoBackup.fingerprint(tables(count: 2), images());
      expect(a, isNot(c));
    });

    test('增删一张图后指纹不同', () {
      final base = AutoBackup.fingerprint(tables(), images());
      final more = AutoBackup.fingerprint(tables(), images(extra: 1));
      expect(base, isNot(more));
      final fewer = AutoBackup.fingerprint(tables(), const [ImageStamp('orig_1.jpg', 100, 1000)]);
      expect(base, isNot(fewer));
    });

    test('图片大小或修改时间变化后指纹不同', () {
      final base = AutoBackup.fingerprint(tables(), images());
      final bigger = AutoBackup.fingerprint(tables(), const [ImageStamp('orig_1.jpg', 101, 1000), ImageStamp('thumb_1.png', 20, 1000)]);
      expect(base, isNot(bigger));
      final touched = AutoBackup.fingerprint(tables(), const [ImageStamp('orig_1.jpg', 100, 1001), ImageStamp('thumb_1.png', 20, 1000)]);
      expect(base, isNot(touched));
    });
  });

  group('备份流程', () {
    test('首次备份：写一个新文件并记下指纹', () async {
      final store = MemoryAutoBackupStore();
      final target = FakeTarget(['gongzhuriji_2026-11-15_0300.wrdx']);
      final r = await build(store: store, target: target).run();
      expect(r.ok, isTrue);
      expect(r.skipped, isFalse);
      expect(r.fileName, 'gongzhuriji_2026-11-16_0300.wrdx');
      expect(target.files, ['gongzhuriji_2026-11-16_0300.wrdx']);
      expect(target.deletes, 1); // 旧的那份被删
      expect(store.hash, isNotEmpty);
      expect(store.file, r.fileName);
      expect(store.backupAt, DateTime(2026, 11, 16, 3, 0).millisecondsSinceEpoch);
      expect(store.lastCheck, store.backupAt);
    });

    test('数据不变：跳过不写文件，只更新检查时间', () async {
      final store = MemoryAutoBackupStore();
      final target = FakeTarget();
      final first = await build(store: store, target: target).run();
      expect(first.skipped, isFalse);
      store.lastCheck = 0;

      final second = await build(store: store, target: target, now: DateTime(2026, 11, 17, 3, 0)).run();
      expect(second.skipped, isTrue);
      expect(second.ok, isTrue);
      expect(target.puts, 1); // 没有第二次写入
      expect(target.files, ['gongzhuriji_2026-11-16_0300.wrdx']);
      expect(store.lastCheck, DateTime(2026, 11, 17, 3, 0).millisecondsSinceEpoch);
      expect(store.backupAt, DateTime(2026, 11, 16, 3, 0).millisecondsSinceEpoch); // 备份时间不变
      expect(store.hash, isNotEmpty);
    });

    test('数据有变化：写新文件、删旧文件、更新指纹', () async {
      final store = MemoryAutoBackupStore();
      final target = FakeTarget();
      await build(store: store, target: target).run();
      final oldHash = store.hash;

      final data = tables(name: '黑T');
      final r = await build(
        store: store,
        target: target,
        data: () => data,
        now: DateTime(2026, 11, 17, 3, 0),
      ).run();
      expect(r.skipped, isFalse);
      expect(r.ok, isTrue);
      expect(target.files, ['gongzhuriji_2026-11-17_0300.wrdx']);
      expect(target.puts, 2);
      expect(store.hash, isNot(oldHash));
      expect(store.file, 'gongzhuriji_2026-11-17_0300.wrdx');
    });

    test('加一张图片算数据有变化', () async {
      final store = MemoryAutoBackupStore();
      final target = FakeTarget();
      var imgs = images();
      await build(store: store, target: target, imgs: () => imgs).run();
      imgs = images(extra: 1);
      final r = await build(store: store, target: target, imgs: () => imgs, now: DateTime(2026, 11, 17, 3, 0)).run();
      expect(r.skipped, isFalse);
      expect(target.puts, 2);
    });

    test('写文件失败：旧文件保留、指纹不变、报错', () async {
      final store = MemoryAutoBackupStore();
      final target = FakeTarget(['gongzhuriji_2026-11-15_0300.wrdx']);
      final r = await build(store: store, target: target, failWrite: true).run();
      expect(r.ok, isFalse);
      expect(r.error, isNotNull);
      expect(target.files, ['gongzhuriji_2026-11-15_0300.wrdx']);
      expect(target.deletes, 0);
      expect(store.hash, ''); // 指纹没更新
      expect(store.backupAt, 0);
      expect(store.error, isNotEmpty);
    });

    test('拷贝进公共目录失败：同样保留旧文件、不更新指纹', () async {
      final store = MemoryAutoBackupStore(hash: 'old', backupAt: 1, file: 'gongzhuriji_2026-11-15_0300.wrdx');
      final target = FakeTarget(['gongzhuriji_2026-11-15_0300.wrdx'])..failPut = true;
      final r = await build(store: store, target: target, data: () => tables(name: '黑T')).run();
      expect(r.ok, isFalse);
      expect(target.files, ['gongzhuriji_2026-11-15_0300.wrdx']);
      expect(store.hash, 'old');
      expect(store.backupAt, 1);
    });

    test('只保留最新一份：目录里其它前缀的文件不动', () async {
      final store = MemoryAutoBackupStore();
      final target = FakeTarget(['gongzhuriji_2026-11-14_0300.wrdx', 'other.wrdx', 'gongzhuriji_2026-11-15_0300.wrdx']);
      await build(store: store, target: target).run();
      expect(target.files, ['other.wrdx', 'gongzhuriji_2026-11-16_0300.wrdx']);
    });
  });

  group('打包格式', () {
    test('writeArchive 产出 data.json + images/，文件名用新命名', () async {
      final dir = Directory.systemTemp.createTempSync('t217_zip_');
      ImageStore.root = p.join(dir.path, 'images');
      Directory(ImageStore.root).createSync(recursive: true);
      File(p.join(ImageStore.root, 'orig_1.jpg')).writeAsStringSync('fake-image');
      final out = File(p.join(dir.path, Backup.fileNameFor(DateTime(2026, 11, 16, 3, 0))));
      await Backup.writeArchive(out, tables());

      expect(p.basename(out.path), 'gongzhuriji_2026-11-16_0300.wrdx');
      final archive = ZipDecoder().decodeBytes(out.readAsBytesSync());
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('data.json'));
      expect(names, contains('images/orig_1.jpg'));
      final data = jsonDecode(utf8.decode(archive.findFile('data.json')!.content as List<int>));
      expect(data['schema'], 2);
      dir.deleteSync(recursive: true);
    });
  });

  group('下一个 03:00 的延迟', () {
    test('00:12 → 2h48m', () {
      expect(AutoBackup.untilNextRun(DateTime(2026, 11, 16, 0, 12)), const Duration(hours: 2, minutes: 48));
    });

    test('03:00 整 → 24h', () {
      expect(AutoBackup.untilNextRun(DateTime(2026, 11, 16, 3, 0)), const Duration(hours: 24));
    });

    test('23:59 → 3h01m', () {
      expect(AutoBackup.untilNextRun(DateTime(2026, 11, 16, 23, 59)), const Duration(hours: 3, minutes: 1));
    });

    test('跨月/跨年也对', () {
      expect(AutoBackup.untilNextRun(DateTime(2026, 12, 31, 23, 30)), const Duration(hours: 3, minutes: 30));
      expect(AutoBackup.untilNextRun(DateTime(2026, 11, 30, 4, 0)), const Duration(hours: 23));
    });
  });

  group('启动兜底', () {
    final now = DateTime(2026, 11, 16, 12, 0);
    test('从未检查过 → 要跑', () {
      expect(AutoBackup.shouldRunOnLaunch(0, now), isTrue);
    });
    test('23 小时前 → 不跑', () {
      expect(AutoBackup.shouldRunOnLaunch(now.subtract(const Duration(hours: 23)).millisecondsSinceEpoch, now), isFalse);
    });
    test('25 小时前 → 跑', () {
      expect(AutoBackup.shouldRunOnLaunch(now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch, now), isTrue);
    });
    test('正好 24 小时 → 跑', () {
      expect(AutoBackup.shouldRunOnLaunch(now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch, now), isTrue);
    });
  });
}
