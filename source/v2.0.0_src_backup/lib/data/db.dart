import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrate.dart';
import 'models.dart';
import 'taxonomy.dart';

/// 全局数据版本号：任何写操作后 +1，页面监听它刷新。
final ValueNotifier<int> dataVersion = ValueNotifier(0);
void bump() => dataVersion.value++;

const schemaV2 = [
  '''CREATE TABLE custom_cats(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, parent_id INTEGER, description TEXT, sort_order INTEGER DEFAULT 0)''',
  '''CREATE TABLE dicts(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, name TEXT NOT NULL, description TEXT, sort_order INTEGER DEFAULT 0)''',
  '''CREATE TABLE clothes(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, image TEXT, original_image TEXT, thumb TEXT, extra_images TEXT,
    cat1 TEXT, cat2 TEXT, custom_cat_id INTEGER, status TEXT, seasons TEXT, storage_id INTEGER, brand TEXT, price REAL, extra_wear INTEGER DEFAULT 0,
    purchase_date TEXT, tag_ids TEXT, style TEXT, material TEXT, warmth TEXT, silhouette TEXT, length TEXT, layer TEXT, colors TEXT, note TEXT,
    source TEXT, sort_order INTEGER DEFAULT 0, created_at INTEGER, updated_at INTEGER)''',
  '''CREATE TABLE outfits(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, cover TEXT, type TEXT, clothes_ids TEXT, canvas TEXT,
    occasion_ids TEXT, seasons TEXT, tag_ids TEXT, note TEXT, photos TEXT, created_at INTEGER)''',
  '''CREATE TABLE calendar(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, outfit_id INTEGER, clothes_id INTEGER, created_at INTEGER)''',
  '''CREATE TABLE day_notes(date TEXT PRIMARY KEY, note TEXT)''',
  '''CREATE TABLE trips(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, start_date TEXT, end_date TEXT, created_at INTEGER)''',
  '''CREATE TABLE trip_outfits(id INTEGER PRIMARY KEY AUTOINCREMENT, trip_id INTEGER NOT NULL, outfit_id INTEGER NOT NULL)''',
  '''CREATE TABLE trip_items(id INTEGER PRIMARY KEY AUTOINCREMENT, trip_id INTEGER NOT NULL, clothes_id INTEGER NOT NULL, manual INTEGER DEFAULT 0, packed INTEGER DEFAULT 0)''',
  '''CREATE TABLE tryon_records(id INTEGER PRIMARY KEY AUTOINCREMENT, model_image TEXT, result TEXT, clothes_ids TEXT, created_at INTEGER)''',
  'CREATE INDEX idx_cal_date ON calendar(date)',
];

const v2Tables = ['custom_cats', 'dicts', 'clothes', 'outfits', 'calendar', 'day_notes', 'trips', 'trip_outfits', 'trip_items', 'tryon_records'];

Future<void> seedDefaults(DatabaseExecutor d) async {
  var i = 0;
  for (final n in defaultOccasions) {
    await d.insert('dicts', {'type': 'occasion', 'name': n, 'sort_order': i++});
  }
}

class AppDb {
  AppDb._();
  static final AppDb I = AppDb._();
  late Database db;

  Future<void> open() async {
    final dir = await getDatabasesPath();
    db = await openDatabase(p.join(dir, 'wardrobe.db'), version: 2, onCreate: (d, v) async {
      for (final s in schemaV2) {
        await d.execute(s);
      }
      await seedDefaults(d);
    }, onUpgrade: (d, oldV, newV) async {
      if (oldV < 2) await migrateV1Database(d);
    });
  }

  // ================= 自定义分类 =================
  Future<List<CustomCat>> customCats() async =>
      (await db.query('custom_cats', orderBy: 'sort_order, id')).map(CustomCat.fromMap).toList();
  Future<int> saveCustomCat(CustomCat c) async {
    if (c.id == null) {
      final m = c.toMap()..remove('id');
      m['sort_order'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      c.id = await db.insert('custom_cats', m);
    } else {
      await db.update('custom_cats', c.toMap(), where: 'id=?', whereArgs: [c.id]);
    }
    bump();
    return c.id!;
  }

  Future<void> deleteCustomCat(int id) async {
    final kids = (await db.query('custom_cats', columns: ['id'], where: 'parent_id=?', whereArgs: [id])).map((e) => e['id'] as int).toList();
    final all = [id, ...kids];
    await db.delete('custom_cats', where: 'id IN (${all.join(',')})');
    await db.update('clothes', {'custom_cat_id': null}, where: 'custom_cat_id IN (${all.join(',')})');
    bump();
  }

  Future<void> reorderCustomCats(List<int> ids) async {
    final b = db.batch();
    for (var i = 0; i < ids.length; i++) {
      b.update('custom_cats', {'sort_order': i}, where: 'id=?', whereArgs: [ids[i]]);
    }
    await b.commit(noResult: true);
    bump();
  }

  // ================= 字典 =================
  Future<List<DictItem>> dicts(String type) async =>
      (await db.query('dicts', where: 'type=?', whereArgs: [type], orderBy: 'sort_order, id')).map(DictItem.fromMap).toList();

  Future<int> addDict(String type, String name, {String description = ''}) async {
    final exist = await db.query('dicts', where: 'type=? AND name=?', whereArgs: [type, name]);
    if (exist.isNotEmpty) return exist.first['id'] as int;
    final id = await db.insert('dicts', {'type': type, 'name': name, 'description': description, 'sort_order': DateTime.now().millisecondsSinceEpoch ~/ 1000});
    bump();
    return id;
  }

  Future<void> updateDict(DictItem d) async {
    await db.update('dicts', d.toMap(), where: 'id=?', whereArgs: [d.id]);
    bump();
  }

  Future<void> deleteDict(DictItem d) async {
    await db.delete('dicts', where: 'id=?', whereArgs: [d.id]);
    switch (d.type) {
      case 'storage':
        await db.update('clothes', {'storage_id': null}, where: 'storage_id=?', whereArgs: [d.id]);
      case 'brand':
        await db.update('clothes', {'brand': null}, where: 'brand=?', whereArgs: [d.name]);
      case 'tag':
        for (final c in await allClothes()) {
          if (c.tagIds.remove(d.id)) await db.update('clothes', {'tag_ids': enc(c.tagIds)}, where: 'id=?', whereArgs: [c.id]);
        }
      case 'outfit_tag':
      case 'occasion':
        for (final o in await outfits()) {
          final list = d.type == 'occasion' ? o.occasionIds : o.tagIds;
          if (list.remove(d.id)) await db.update('outfits', o.toMap(), where: 'id=?', whereArgs: [o.id]);
        }
    }
    bump();
  }

  Future<void> reorderDicts(List<int> ids) async {
    final b = db.batch();
    for (var i = 0; i < ids.length; i++) {
      b.update('dicts', {'sort_order': i}, where: 'id=?', whereArgs: [ids[i]]);
    }
    await b.commit(noResult: true);
    bump();
  }

  // ================= 衣物 =================
  Future<Map<int, ({int n, String? last})>> _wearStats() async {
    final res = <int, ({int n, String? last})>{};
    final outfitsById = {for (final o in await outfits()) o.id!: o};
    for (final r in (await db.query('calendar')).map(CalRecord.fromMap)) {
      final ids = r.clothesId != null ? [r.clothesId!] : (outfitsById[r.outfitId]?.clothesIds ?? const <int>[]);
      for (final id in ids.toSet()) {
        final cur = res[id];
        final last = cur?.last == null || r.date.compareTo(cur!.last!) > 0 ? r.date : cur.last;
        res[id] = (n: (cur?.n ?? 0) + 1, last: last);
      }
    }
    return res;
  }

  /// 全部衣物（含丢弃），带穿着统计
  Future<List<Clothes>> allClothes() async {
    final list = (await db.query('clothes', orderBy: 'sort_order DESC, id DESC')).map(Clothes.fromMap).toList();
    final ws = await _wearStats();
    for (final c in list) {
      final s = ws[c.id];
      c.calWear = s?.n ?? 0;
      c.lastWear = s?.last;
    }
    return list;
  }

  Future<Clothes?> clothesById(int id) async {
    final r = await db.query('clothes', where: 'id=?', whereArgs: [id]);
    if (r.isEmpty) return null;
    final c = Clothes.fromMap(r.first);
    final s = (await _wearStats())[id];
    c.calWear = s?.n ?? 0;
    c.lastWear = s?.last;
    return c;
  }

  Future<Map<int, Clothes>> clothesMap() async => {for (final c in await allClothes()) c.id!: c};

  Future<int> saveClothes(Clothes c) async {
    c.updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (c.id == null) {
      final m = c.toMap()..remove('id');
      m['sort_order'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      c.id = await db.insert('clothes', m);
    } else {
      await db.update('clothes', c.toMap(), where: 'id=?', whereArgs: [c.id]);
    }
    bump();
    return c.id!;
  }

  Future<void> deleteClothes(int id) async {
    await db.delete('clothes', where: 'id=?', whereArgs: [id]);
    await db.delete('trip_items', where: 'clothes_id=?', whereArgs: [id]);
    await db.delete('calendar', where: 'clothes_id=?', whereArgs: [id]);
    for (final o in await outfits()) {
      if (o.clothesIds.remove(id)) await db.update('outfits', {'clothes_ids': enc(o.clothesIds)}, where: 'id=?', whereArgs: [o.id]);
    }
    bump();
  }

  // ================= 穿搭 =================
  Future<List<Outfit>> outfits() async => (await db.query('outfits', orderBy: 'created_at DESC')).map(Outfit.fromMap).toList();
  Future<Outfit?> outfitById(int id) async {
    final r = await db.query('outfits', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Outfit.fromMap(r.first);
  }

  Future<int> saveOutfit(Outfit o) async {
    if (o.id == null) {
      final m = o.toMap()..remove('id');
      o.id = await db.insert('outfits', m);
    } else {
      await db.update('outfits', o.toMap(), where: 'id=?', whereArgs: [o.id]);
    }
    bump();
    return o.id!;
  }

  Future<void> deleteOutfit(int id) async {
    await db.delete('outfits', where: 'id=?', whereArgs: [id]);
    await db.delete('calendar', where: 'outfit_id=?', whereArgs: [id]);
    final trips = (await db.query('trip_outfits', where: 'outfit_id=?', whereArgs: [id])).map((e) => e['trip_id'] as int).toSet();
    await db.delete('trip_outfits', where: 'outfit_id=?', whereArgs: [id]);
    for (final t in trips) {
      await _cleanTrip(t);
    }
    bump();
  }

  // ================= 日历 =================
  Future<List<CalRecord>> calendarRange(String from, String to) async => (await db.query('calendar',
          where: 'date>=? AND date<=?', whereArgs: [from, to], orderBy: 'date, created_at'))
      .map(CalRecord.fromMap)
      .toList();

  Future<List<CalRecord>> calendarDay(String date) => calendarRange(date, date);

  Future<void> addCal(CalRecord r) async {
    final dup = await db.query('calendar',
        where: 'date=? AND IFNULL(outfit_id,-1)=? AND IFNULL(clothes_id,-1)=?', whereArgs: [r.date, r.outfitId ?? -1, r.clothesId ?? -1]);
    if (dup.isNotEmpty) return;
    await db.insert('calendar', r.toMap()..remove('id'));
    bump();
  }

  Future<void> deleteCal(int id) async {
    await db.delete('calendar', where: 'id=?', whereArgs: [id]);
    bump();
  }

  Future<String> dayNote(String date) async {
    final r = await db.query('day_notes', where: 'date=?', whereArgs: [date]);
    return r.isEmpty ? '' : (r.first['note'] as String? ?? '');
  }

  Future<Map<String, String>> dayNotesRange(String from, String to) async => {
        for (final r in await db.query('day_notes', where: 'date>=? AND date<=?', whereArgs: [from, to])) r['date'] as String: (r['note'] as String?) ?? ''
      };

  Future<void> setDayNote(String date, String note) async {
    if (note.trim().isEmpty) {
      await db.delete('day_notes', where: 'date=?', whereArgs: [date]);
    } else {
      await db.insert('day_notes', {'date': date, 'note': note}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    bump();
  }

  // ================= 行程 =================
  Future<List<Trip>> trips() async => (await db.query('trips', orderBy: 'start_date DESC, id DESC')).map(Trip.fromMap).toList();
  Future<Trip?> tripById(int id) async {
    final r = await db.query('trips', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Trip.fromMap(r.first);
  }

  Future<int> saveTrip(Trip t) async {
    if (t.id == null) {
      t.id = await db.insert('trips', t.toMap()..remove('id'));
    } else {
      await db.update('trips', t.toMap(), where: 'id=?', whereArgs: [t.id]);
    }
    bump();
    return t.id!;
  }

  Future<void> deleteTrip(int id) async {
    await db.delete('trips', where: 'id=?', whereArgs: [id]);
    await db.delete('trip_items', where: 'trip_id=?', whereArgs: [id]);
    await db.delete('trip_outfits', where: 'trip_id=?', whereArgs: [id]);
    bump();
  }

  Future<List<int>> tripOutfitIds(int tripId) async =>
      (await db.query('trip_outfits', where: 'trip_id=?', whereArgs: [tripId], orderBy: 'id')).map((e) => e['outfit_id'] as int).toList();

  Future<List<TripItem>> tripItems(int tripId) async =>
      (await db.query('trip_items', where: 'trip_id=?', whereArgs: [tripId], orderBy: 'id')).map(TripItem.fromMap).toList();

  Future<void> addTripOutfits(int tripId, List<int> outfitIds) async {
    final have = (await tripOutfitIds(tripId)).toSet();
    final items = {for (final i in await tripItems(tripId)) i.clothesId};
    for (final oid in outfitIds) {
      if (have.contains(oid)) continue;
      await db.insert('trip_outfits', {'trip_id': tripId, 'outfit_id': oid});
      final o = await outfitById(oid);
      for (final cid in o?.clothesIds ?? const <int>[]) {
        if (items.add(cid)) await db.insert('trip_items', {'trip_id': tripId, 'clothes_id': cid, 'manual': 0, 'packed': 0});
      }
    }
    bump();
  }

  Future<void> addTripClothes(int tripId, List<int> clothesIds) async {
    final items = {for (final i in await tripItems(tripId)) i.clothesId: i};
    for (final cid in clothesIds) {
      final ex = items[cid];
      if (ex == null) {
        await db.insert('trip_items', {'trip_id': tripId, 'clothes_id': cid, 'manual': 1, 'packed': 0});
      } else if (!ex.manual) {
        await db.update('trip_items', {'manual': 1}, where: 'id=?', whereArgs: [ex.id]);
      }
    }
    bump();
  }

  Future<void> removeTripOutfit(int tripId, int outfitId) async {
    await db.delete('trip_outfits', where: 'trip_id=? AND outfit_id=?', whereArgs: [tripId, outfitId]);
    await _cleanTrip(tripId);
    bump();
  }

  Future<void> removeTripItem(int tripId, int clothesId) async {
    // 单独添加的取消“单独”，若无搭配来源则删除
    await db.update('trip_items', {'manual': 0}, where: 'trip_id=? AND clothes_id=?', whereArgs: [tripId, clothesId]);
    await _cleanTrip(tripId, forceRemove: clothesId);
    bump();
  }

  Future<void> _cleanTrip(int tripId, {int? forceRemove}) async {
    final ids = await tripOutfitIds(tripId);
    final used = <int>{};
    for (final oid in ids) {
      used.addAll((await outfitById(oid))?.clothesIds ?? const []);
    }
    for (final it in await tripItems(tripId)) {
      if (it.manual) continue;
      if (!used.contains(it.clothesId) || it.clothesId == forceRemove) {
        await db.delete('trip_items', where: 'id=?', whereArgs: [it.id]);
      }
    }
  }

  Future<void> setPacked(int itemId, bool v) async {
    await db.update('trip_items', {'packed': v ? 1 : 0}, where: 'id=?', whereArgs: [itemId]);
    bump();
  }

  // ================= AI 试衣记录 =================
  Future<List<TryOnRecord>> tryOnRecords() async =>
      (await db.query('tryon_records', orderBy: 'created_at DESC')).map(TryOnRecord.fromMap).toList();
  Future<void> addTryOn(TryOnRecord r) async {
    await db.insert('tryon_records', r.toMap()..remove('id'));
    bump();
  }

  Future<void> deleteTryOn(int id) async {
    await db.delete('tryon_records', where: 'id=?', whereArgs: [id]);
    bump();
  }

  // ================= 备份 =================
  Future<Map<String, Object>> exportTables() async {
    final out = <String, Object>{'schema': 2, 'app': 'my_wardrobe', 'exportedAt': DateTime.now().toIso8601String()};
    for (final t in v2Tables) {
      out[t] = await db.query(t);
    }
    return out;
  }

  /// 用备份覆盖当前数据。支持 2.0 备份包（schema 2）和 1.0 旧备份（data.json，version 1）。
  Future<void> importTables(Map<String, dynamic> data) async {
    await db.transaction((t) async {
      for (final tb in v2Tables) {
        await t.delete(tb);
      }
      await t.execute("DELETE FROM sqlite_sequence");
      if (data['schema'] == 2) {
        for (final tb in v2Tables) {
          for (final row in (data[tb] as List? ?? [])) {
            await t.insert(tb, Map<String, Object?>.from(row as Map));
          }
        }
      } else {
        final old = <String, List<Map<String, Object?>>>{};
        for (final tb in const ['categories', 'dicts', 'clothes', 'outfits', 'calendar', 'trips', 'trip_items']) {
          old[tb] = [for (final r in (data[tb] as List? ?? [])) Map<String, Object?>.from(r as Map)];
        }
        await convertV1(old, t);
      }
    });
    bump();
  }
}
