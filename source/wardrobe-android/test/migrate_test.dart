import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_wardrobe/data/migrate.dart';
import 'package:my_wardrobe/data/models.dart';
import 'package:my_wardrobe/services/recommend.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const v1Schema = [
  '''CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, parent_id INTEGER,
        slot TEXT NOT NULL, system INTEGER DEFAULT 0, hidden INTEGER DEFAULT 0, sort_order INTEGER DEFAULT 0)''',
  '''CREATE TABLE dicts(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, name TEXT NOT NULL, sort_order INTEGER DEFAULT 0)''',
  '''CREATE TABLE clothes(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, original_path TEXT NOT NULL, cutout_path TEXT,
        thumb_path TEXT, category_l1_id INTEGER, category_l2_id INTEGER, colors TEXT, materials TEXT, seasons TEXT, warmth TEXT, fit TEXT,
        length TEXT, layer_role TEXT, styles TEXT, brand_id INTEGER, price REAL, purchase_date TEXT, storage_id INTEGER, tag_ids TEXT,
        note TEXT, status TEXT DEFAULT 'active', in_auto_outfit INTEGER DEFAULT 1, manual_fields TEXT, wear_count INTEGER DEFAULT 0,
        last_wear_date TEXT, sort_order INTEGER DEFAULT 0, created_at INTEGER)''',
  '''CREATE TABLE outfits(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, items TEXT NOT NULL, item_key TEXT,
        cover_path TEXT, occasion_ids TEXT, tag_ids TEXT, seasons TEXT, source TEXT, bg INTEGER DEFAULT 0, wear_count INTEGER DEFAULT 0,
        last_wear_date TEXT, created_at INTEGER)''',
  '''CREATE TABLE calendar(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, outfit_id INTEGER,
        clothes_ids TEXT, photos TEXT, note TEXT, temp REAL)''',
  '''CREATE TABLE trips(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, city TEXT, start_date TEXT,
        end_date TEXT, note TEXT)''',
  '''CREATE TABLE trip_items(id INTEGER PRIMARY KEY AUTOINCREMENT, trip_id INTEGER NOT NULL, clothes_id INTEGER,
        custom_name TEXT, qty INTEGER DEFAULT 1, packed INTEGER DEFAULT 0)''',
  'CREATE INDEX idx_clothes_cat ON clothes(category_l1_id, status)',
  'CREATE INDEX idx_cal_date ON calendar(date)',
];

void main() {
  sqfliteFfiInit();
  test('v1 -> v2 migration keeps data', () async {
    final f = databaseFactoryFfi;
    final path = '${Directory.systemTemp.path}/mig_test_${DateTime.now().microsecondsSinceEpoch}.db';
    var d = await f.openDatabase(path, options: OpenDatabaseOptions(version: 1, onCreate: (d, v) async {
      for (final s in v1Schema) {
        await d.execute(s);
      }
      await d.insert('categories', {'id': 1, 'name': '上衣', 'slot': 'top', 'system': 1});
      await d.insert('categories', {'id': 2, 'name': 'T恤', 'parent_id': 1, 'slot': 'top', 'system': 1});
      await d.insert('categories', {'id': 3, 'name': '下装', 'slot': 'bottom', 'system': 1});
      await d.insert('categories', {'id': 4, 'name': '牛仔裤', 'parent_id': 3, 'slot': 'bottom', 'system': 1});
      await d.insert('categories', {'id': 5, 'name': '我的通勤', 'slot': 'top', 'system': 0});
      await d.insert('dicts', {'id': 1, 'type': 'occasion', 'name': '通勤'});
      await d.insert('dicts', {'id': 2, 'type': 'brand', 'name': 'Uniqlo 优衣库'});
      await d.insert('dicts', {'id': 3, 'type': 'storage', 'name': '大衣柜'});
      await d.insert('dicts', {'id': 4, 'type': 'tag', 'name': '心头好'});
      await d.insert('clothes', {
        'id': 10, 'name': '白T', 'original_path': 'orig_1.jpg', 'cutout_path': 'cut_1.png', 'thumb_path': 'thumb_1.png',
        'category_l1_id': 1, 'category_l2_id': 2, 'colors': jsonEncode(['white', 'black']), 'materials': jsonEncode(['棉']),
        'seasons': jsonEncode(['summer', 'spring']), 'warmth': 'thin', 'fit': 'loose', 'length': 'regular', 'layer_role': 'base',
        'styles': jsonEncode(['casual']), 'brand_id': 2, 'price': 99.0, 'storage_id': 3, 'tag_ids': jsonEncode(['4']),
        'status': 'active', 'wear_count': 3, 'created_at': 1,
      });
      await d.insert('clothes', {
        'id': 11, 'name': '', 'original_path': 'orig_2.jpg', 'category_l1_id': 3, 'category_l2_id': 4, 'colors': jsonEncode(['blue']),
        'status': 'disposed', 'wear_count': 1, 'created_at': 2,
      });
      await d.insert('clothes', {'id': 12, 'name': '自定义', 'original_path': 'orig_3.jpg', 'category_l1_id': 5, 'status': 'idle', 'created_at': 3});
      await d.insert('outfits', {
        'id': 20, 'name': '上班', 'items': jsonEncode([{'c': 10, 'x': 0, 'y': 0, 's': 1, 'z': 0}, {'c': 11, 'x': 0, 'y': 0, 's': 1, 'z': 1}]),
        'cover_path': 'cover_1.png', 'occasion_ids': jsonEncode(['1']), 'seasons': jsonEncode(['summer']), 'source': 'manual', 'created_at': 5,
      });
      await d.insert('calendar', {'date': '2026-10-01', 'outfit_id': 20, 'clothes_ids': jsonEncode([10, 11]), 'photos': jsonEncode(['p1.jpg']), 'note': '开会'});
      await d.insert('calendar', {'date': '2026-10-02', 'clothes_ids': jsonEncode([10]), 'photos': '[]', 'note': ''});
      await d.insert('trips', {'id': 1, 'name': '出差', 'start_date': '2026-11-01', 'end_date': '2026-11-03'});
      await d.insert('trip_items', {'trip_id': 1, 'clothes_id': 10, 'packed': 1});
      await d.insert('trip_items', {'trip_id': 1, 'custom_name': '充电器'});
    }));
    // 升级
    await d.close();
    d = await f.openDatabase(path, options: OpenDatabaseOptions(version: 2, onUpgrade: (d, o, n) => migrateV1Database(d)));
    final clothes = (await d.query('clothes', orderBy: 'id')).map(Clothes.fromMap).toList();
    expect(clothes.length, 3);
    final t = clothes[0];
    expect(t.name, '白T');
    expect(t.cat1, '上装');
    expect(t.cat2, 'T恤');
    expect(t.colors, ['白色', '黑色']);
    expect(t.seasons.toSet(), {'夏季', '春季'});
    expect(t.warmth, '薄');
    expect(t.silhouette, '宽松');
    expect(t.material, '棉');
    expect(t.style, '休闲');
    expect(t.brand, 'Uniqlo 优衣库');
    expect(t.storageId, 3);
    expect(t.tagIds, [4]);
    expect(t.image, 'cut_1.png');
    expect(t.originalImage, 'orig_1.jpg');
    expect(t.extraWear, 1); // 3 次 - 日历 2 次
    expect(clothes[1].status, '丢弃');
    expect(clothes[1].cat1, '下装');
    expect(clothes[2].status, '拥有');
    expect(clothes[2].customCatId, isNotNull);
    final o = Outfit.fromMap((await d.query('outfits')).first);
    expect(o.clothesIds, [10, 11]);
    expect(o.occasionIds, [1]);
    expect(o.seasons, ['夏季']);
    expect(o.photos, ['p1.jpg']);
    final cal = await d.query('calendar', orderBy: 'date');
    expect(cal.length, 2);
    expect(cal[0]['outfit_id'], 20);
    expect(cal[1]['clothes_id'], 10);
    expect((await d.query('day_notes')).first['note'], '开会');
    expect((await d.query('trip_items')).length, 1);
    final tables = (await d.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")).map((e) => e['name']).toSet();
    expect(tables.any((e) => '$e'.startsWith('old_')), false);
    // 新表可正常插入
    await d.insert('clothes', Clothes(name: 'new').toMap()..remove('id'));
    expect((await d.query('clothes')).length, 4);
    await d.close();
  });

  test('recommender builds outfits and respects filters', () {
    var id = 0;
    Clothes c(String c1, String c2, {String? warmth, List<String> colors = const [], String? layer}) =>
        Clothes(id: ++id, cat1: c1, cat2: c2, warmth: warmth, colors: colors, layer: layer);
    final all = [
      c('上装', 'T恤', warmth: '薄', colors: ['白色']),
      c('上装', '衬衫', warmth: '适中', colors: ['蓝色'], layer: '中间层'),
      c('下装', '牛仔裤', warmth: '适中', colors: ['蓝色']),
      c('外套', '夹克', warmth: '保暖', colors: ['黑色']),
      c('鞋履', '运动鞋', colors: ['白色']),
      c('包袋', '双肩包'),
    ];
    final ctx = ctxFromWeather(max: 16, min: 8);
    final r = Recommender(all, ctx, disabledCats: [], disabledSlots: []).generate(count: 5);
    expect(r, isNotEmpty);
    expect(r.every((s) => s.items.any((e) => e.cat1 == '下装')), true);
    final noOuter = Recommender(all, ctx, disabledCats: ['外套'], disabledSlots: ['上装外搭来源']).generate(count: 5);
    expect(noOuter.every((s) => !s.items.any((e) => e.cat1 == '外套')), true);
    final hot = Recommender(all, ctxFromWeather(max: 33, min: 27), disabledCats: [], disabledSlots: []).generate(count: 5);
    expect(hot.every((s) => !s.items.any((e) => e.cat1 == '外套')), true);
    final anchor = Recommender(all, ctx, anchorId: 6, disabledCats: ['包袋'], disabledSlots: []).generate(count: 3);
    expect(anchor.isNotEmpty && anchor.every((s) => s.items.any((e) => e.id == 6)), true);
    final missing = Recommender([all[0]], ctx, disabledCats: [], disabledSlots: []);
    expect(missing.generate(), isEmpty);
    expect(missing.missingHint(), '缺少下装');
  });
}
