import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'models.dart';
import 'taxonomy.dart';

/// 1.0（数据库 v1）→ 2.0（v2）升级：旧表改名 → 建新表 → 逐行转换 → 删旧表。用户数据不丢。
Future<void> migrateV1Database(Database d) async {
  const oldTables = ['categories', 'dicts', 'clothes', 'outfits', 'calendar', 'trips', 'trip_items'];
  final existing = (await d.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")).map((e) => e['name'] as String).toSet();
  for (final t in oldTables) {
    if (existing.contains(t)) await d.execute('ALTER TABLE $t RENAME TO old_$t');
  }
  await d.execute('DROP INDEX IF EXISTS idx_clothes_cat');
  await d.execute('DROP INDEX IF EXISTS idx_cal_date');
  for (final s in schemaV2) {
    await d.execute(s);
  }
  final old = <String, List<Map<String, Object?>>>{};
  for (final t in oldTables) {
    old[t] = existing.contains(t) ? (await d.query('old_$t')).map((e) => Map<String, Object?>.from(e)).toList() : [];
  }
  await convertV1(old, d);
  for (final t in oldTables) {
    if (existing.contains(t)) await d.execute('DROP TABLE old_$t');
  }
}

const _oldL1 = {'上衣': '上装', '下装': '下装', '连衣裙/连体': '连衣裙', '外套': '外套', '鞋': '鞋履', '包': '包袋', '配饰': '配饰'};

List<String> _l(dynamic v) {
  if (v == null || v == '') return [];
  try {
    return List<String>.from((jsonDecode(v as String) as List).map((e) => '$e'));
  } catch (_) {
    return [];
  }
}

/// 把 v1 的表数据写进 v2 表（executor 里应已是空的 v2 表）
Future<void> convertV1(Map<String, List<Map<String, Object?>>> old, DatabaseExecutor d) async {
  // ---- 字典（场合、标签、穿搭标签、收纳位置、品牌）原 id 保留 ----
  final brandName = <int, String>{};
  final hasOccasion = old['dicts']!.any((e) => e['type'] == 'occasion');
  for (final r in old['dicts']!) {
    final type = r['type'] as String;
    if (type == 'brand') brandName[r['id'] as int] = r['name'] as String;
    await d.insert('dicts', {'id': r['id'], 'type': type, 'name': r['name'], 'description': '', 'sort_order': r['sort_order'] ?? 0});
  }
  if (!hasOccasion) await seedDefaults(d);

  // ---- 分类：系统分类映射到新的衣物品类，用户自建分类变成自定义分类 ----
  final cats = {for (final r in old['categories']!) r['id'] as int: r};
  final customId = <int, int>{}; // 旧分类 id -> 新自定义分类 id
  var sort = 0;
  for (final r in old['categories']!.where((e) => e['system'] != 1 && e['parent_id'] == null)) {
    customId[r['id'] as int] = await d.insert('custom_cats', {'name': r['name'], 'parent_id': null, 'description': '', 'sort_order': sort++});
  }
  for (final r in old['categories']!.where((e) => e['system'] != 1 && e['parent_id'] != null)) {
    final parent = customId[r['parent_id']];
    customId[r['id'] as int] = await d.insert('custom_cats', {'name': r['name'], 'parent_id': parent, 'description': '', 'sort_order': sort++});
  }

  // ---- 日历先算每件衣服日历次数（为了保留旧的穿着次数）----
  final outfitItems = <int, List<int>>{};
  for (final o in old['outfits']!) {
    try {
      outfitItems[o['id'] as int] = (jsonDecode(o['items'] as String) as List).map((e) => (e as Map)['c'] as int).toList();
    } catch (_) {
      outfitItems[o['id'] as int] = [];
    }
  }
  final calCount = <int, int>{};
  for (final e in old['calendar']!) {
    var ids = <int>[];
    try {
      ids = List<int>.from(jsonDecode((e['clothes_ids'] as String?) ?? '[]'));
    } catch (_) {}
    if (e['outfit_id'] != null && ids.isEmpty) ids = outfitItems[e['outfit_id']] ?? [];
    for (final id in ids.toSet()) {
      calCount[id] = (calCount[id] ?? 0) + 1;
    }
  }

  // ---- 衣物 ----
  for (final r in old['clothes']!) {
    String? c1, c2;
    int? custom;
    final l1 = cats[r['category_l1_id']];
    final l2 = cats[r['category_l2_id']];
    if (l1 != null) {
      if (l1['system'] == 1) {
        c1 = _oldL1[l1['name']];
      } else {
        custom = customId[l1['id']];
      }
    }
    if (l2 != null) {
      if (l2['system'] == 1) {
        final m = taggerCategoryMap[l2['name']];
        if (m != null) {
          c1 = m[0];
          c2 = m[1];
        }
      } else {
        custom = customId[l2['id']] ?? custom;
      }
    }
    final colors = _l(r['colors']).map((e) => taggerColorMap[e]).whereType<String>().toList();
    final seasons = _l(r['seasons']).map((e) => taggerSeasonMap[e]).whereType<String>().toList();
    final mats = _l(r['materials']);
    final styles = _l(r['styles']);
    final orig = r['original_path'] as String?;
    final cut = r['cutout_path'] as String?;
    final oldWear = (r['wear_count'] as int?) ?? 0;
    final extra = oldWear - (calCount[r['id']] ?? 0);
    final c = Clothes(
      id: r['id'] as int,
      name: (r['name'] as String?) ?? '',
      image: cut ?? orig,
      originalImage: orig,
      thumb: r['thumb_path'] as String?,
      cat1: c1,
      cat2: c2,
      customCatId: custom,
      status: r['status'] == 'disposed' ? '丢弃' : '拥有',
      seasons: seasons,
      storageId: r['storage_id'] as int?,
      brand: brandName[r['brand_id']],
      price: (r['price'] as num?)?.toDouble(),
      extraWear: extra > 0 ? extra : 0,
      purchaseDate: r['purchase_date'] as String?,
      tagIds: _l(r['tag_ids']).map(int.tryParse).whereType<int>().toList(),
      style: styles.isEmpty ? null : taggerStyleMap[styles.first],
      material: mats.isEmpty ? null : (taggerMaterialMap[mats.first] ?? mats.first),
      warmth: taggerWarmthMap[r['warmth']],
      silhouette: taggerFitMap[r['fit']],
      length: taggerLengthMap[r['length']],
      layer: taggerLayerMap[r['layer_role']],
      colors: colors.take(3).toList(),
      note: (r['note'] as String?) ?? '',
      source: 'v1',
      sortOrder: (r['sort_order'] as int?) ?? 0,
      createdAt: r['created_at'] as int?,
    );
    await d.insert('clothes', c.toMap());
  }

  // ---- 穿搭 ----
  final outfitPhotos = <int, List<String>>{};
  for (final e in old['calendar']!) {
    if (e['outfit_id'] != null) outfitPhotos.putIfAbsent(e['outfit_id'] as int, () => []).addAll(_l(e['photos']));
  }
  for (final r in old['outfits']!) {
    final src = r['source'] as String?;
    final o = Outfit(
      id: r['id'] as int,
      name: (r['name'] as String?) ?? '',
      cover: r['cover_path'] as String?,
      type: src == 'photo' ? 'photo' : (src == 'auto' ? 'auto' : 'collage'),
      clothesIds: outfitItems[r['id']] ?? [],
      occasionIds: _l(r['occasion_ids']).map(int.tryParse).whereType<int>().toList(),
      seasons: _l(r['seasons']).map((e) => taggerSeasonMap[e]).whereType<String>().toList(),
      tagIds: _l(r['tag_ids']).map(int.tryParse).whereType<int>().toList(),
      photos: outfitPhotos[r['id']] ?? [],
      createdAt: r['created_at'] as int?,
    );
    await d.insert('outfits', o.toMap());
  }

  // ---- 日历 ----
  final notes = <String, List<String>>{};
  for (final e in old['calendar']!) {
    final date = e['date'] as String;
    final note = (e['note'] as String?) ?? '';
    if (note.trim().isNotEmpty) notes.putIfAbsent(date, () => []).add(note.trim());
    if (e['outfit_id'] != null) {
      await d.insert('calendar', {'date': date, 'outfit_id': e['outfit_id'], 'clothes_id': null, 'created_at': DateTime.now().millisecondsSinceEpoch});
    } else {
      var ids = <int>[];
      try {
        ids = List<int>.from(jsonDecode((e['clothes_ids'] as String?) ?? '[]'));
      } catch (_) {}
      for (final id in ids.toSet()) {
        await d.insert('calendar', {'date': date, 'outfit_id': null, 'clothes_id': id, 'created_at': DateTime.now().millisecondsSinceEpoch});
      }
    }
  }
  for (final n in notes.entries) {
    await d.insert('day_notes', {'date': n.key, 'note': n.value.join('\n')}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---- 行程 ----
  for (final t in old['trips']!) {
    await d.insert('trips', {
      'id': t['id'], 'name': t['name'], 'start_date': t['start_date'], 'end_date': t['end_date'],
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
  for (final it in old['trip_items']!) {
    if (it['clothes_id'] == null) continue; // 旧版自定义文字条目不再支持
    await d.insert('trip_items', {'trip_id': it['trip_id'], 'clothes_id': it['clothes_id'], 'manual': 1, 'packed': it['packed'] == 1 ? 1 : 0});
  }
}
