import 'dart:convert';

List<String> strList(dynamic v) {
  if (v == null || v == '') return <String>[];
  try {
    return List<String>.from((jsonDecode(v as String) as List).map((e) => '$e'));
  } catch (_) {
    return <String>[];
  }
}

List<int> intList(dynamic v) {
  if (v == null || v == '') return <int>[];
  try {
    return List<int>.from((jsonDecode(v as String) as List).map((e) => e is int ? e : int.parse('$e')));
  } catch (_) {
    return <int>[];
  }
}

String enc(Object v) => jsonEncode(v);

/// 自定义分类（两级）
class CustomCat {
  int? id;
  String name;
  int? parentId;
  String description;
  int sortOrder;
  CustomCat({this.id, required this.name, this.parentId, this.description = '', this.sortOrder = 0});
  factory CustomCat.fromMap(Map<String, Object?> m) => CustomCat(
      id: m['id'] as int?, name: m['name'] as String, parentId: m['parent_id'] as int?,
      description: (m['description'] as String?) ?? '', sortOrder: (m['sort_order'] as int?) ?? 0);
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'parent_id': parentId, 'description': description, 'sort_order': sortOrder};
}

/// 标签 / 穿搭标签 / 场合 / 自定义品牌 / 收纳位置
class DictItem {
  int? id;
  String type;
  String name;
  String description;
  int sortOrder;
  DictItem({this.id, required this.type, required this.name, this.description = '', this.sortOrder = 0});
  factory DictItem.fromMap(Map<String, Object?> m) => DictItem(
      id: m['id'] as int?, type: m['type'] as String, name: m['name'] as String,
      description: (m['description'] as String?) ?? '', sortOrder: (m['sort_order'] as int?) ?? 0);
  Map<String, Object?> toMap() => {'id': id, 'type': type, 'name': name, 'description': description, 'sort_order': sortOrder};
}

class Clothes {
  int? id;
  String name;
  String? image; // 处理后的主图（相对路径）
  String? originalImage;
  String? thumb;
  List<String> extraImages;
  String? cat1, cat2; // 系统衣物品类
  int? customCatId;
  String status;
  List<String> seasons;
  int? storageId;
  String? brand;
  double? price;
  int extraWear;
  String? purchaseDate;
  List<int> tagIds;
  String? style, material, warmth, silhouette, length, layer;
  List<String> colors; // 主色、配色1、配色2
  String note;
  String source;
  int sortOrder;
  int createdAt;
  int updatedAt;

  // 运行时：日历统计
  int calWear = 0;
  String? lastWear;

  Clothes({
    this.id, this.name = '', this.image, this.originalImage, this.thumb, List<String>? extraImages, this.cat1, this.cat2,
    this.customCatId, this.status = '拥有', List<String>? seasons, this.storageId, this.brand, this.price, this.extraWear = 0,
    this.purchaseDate, List<int>? tagIds, this.style, this.material, this.warmth, this.silhouette, this.length, this.layer,
    List<String>? colors, this.note = '', this.source = '', this.sortOrder = 0, int? createdAt, int? updatedAt,
  })  : extraImages = extraImages ?? [], seasons = seasons ?? [], tagIds = tagIds ?? [], colors = colors ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  int get wearCount => calWear + extraWear;
  String get displayName => name.isEmpty ? (cat2 ?? cat1 ?? '未命名') : name;
  String? get listImage => thumb ?? image ?? originalImage;
  String? get mainImage => image ?? originalImage;
  String get cat1OrUnknown => (cat1 == null || cat1!.isEmpty) ? '未识别' : cat1!;
  String get catText => cat1 == null || cat1!.isEmpty ? '' : (cat2 == null || cat2!.isEmpty ? cat1! : '$cat1 / $cat2');

  Clothes copy() => Clothes.fromMap(toMap())
    ..calWear = calWear
    ..lastWear = lastWear;

  factory Clothes.fromMap(Map<String, Object?> m) => Clothes(
        id: m['id'] as int?, name: (m['name'] as String?) ?? '', image: m['image'] as String?, originalImage: m['original_image'] as String?,
        thumb: m['thumb'] as String?, extraImages: strList(m['extra_images']), cat1: m['cat1'] as String?, cat2: m['cat2'] as String?,
        customCatId: m['custom_cat_id'] as int?, status: (m['status'] as String?) ?? '拥有', seasons: strList(m['seasons']),
        storageId: m['storage_id'] as int?, brand: m['brand'] as String?, price: (m['price'] as num?)?.toDouble(),
        extraWear: (m['extra_wear'] as int?) ?? 0, purchaseDate: m['purchase_date'] as String?, tagIds: intList(m['tag_ids']),
        style: m['style'] as String?, material: m['material'] as String?, warmth: m['warmth'] as String?,
        silhouette: m['silhouette'] as String?, length: m['length'] as String?, layer: m['layer'] as String?,
        colors: strList(m['colors']), note: (m['note'] as String?) ?? '', source: (m['source'] as String?) ?? '',
        sortOrder: (m['sort_order'] as int?) ?? 0, createdAt: m['created_at'] as int?, updatedAt: m['updated_at'] as int?,
      );

  Map<String, Object?> toMap() => {
        'id': id, 'name': name, 'image': image, 'original_image': originalImage, 'thumb': thumb, 'extra_images': enc(extraImages),
        'cat1': cat1, 'cat2': cat2, 'custom_cat_id': customCatId, 'status': status, 'seasons': enc(seasons), 'storage_id': storageId,
        'brand': brand, 'price': price, 'extra_wear': extraWear, 'purchase_date': purchaseDate, 'tag_ids': enc(tagIds),
        'style': style, 'material': material, 'warmth': warmth, 'silhouette': silhouette, 'length': length, 'layer': layer,
        'colors': enc(colors), 'note': note, 'source': source, 'sort_order': sortOrder, 'created_at': createdAt, 'updated_at': updatedAt,
      };
}

class Outfit {
  int? id;
  String name;
  String? cover;
  String type; // collage / photo / flip / auto
  List<int> clothesIds;
  String canvas; // 拼图元素 JSON（可重新编辑）
  List<int> occasionIds;
  List<String> seasons;
  List<int> tagIds;
  String note;
  List<String> photos; // 穿搭照
  int createdAt;
  Outfit({
    this.id, this.name = '', this.cover, this.type = 'collage', List<int>? clothesIds, this.canvas = '', List<int>? occasionIds,
    List<String>? seasons, List<int>? tagIds, this.note = '', List<String>? photos, int? createdAt,
  })  : clothesIds = clothesIds ?? [], occasionIds = occasionIds ?? [], seasons = seasons ?? [], tagIds = tagIds ?? [],
        photos = photos ?? [], createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Outfit.fromMap(Map<String, Object?> m) => Outfit(
        id: m['id'] as int?, name: (m['name'] as String?) ?? '', cover: m['cover'] as String?, type: (m['type'] as String?) ?? 'collage',
        clothesIds: intList(m['clothes_ids']), canvas: (m['canvas'] as String?) ?? '', occasionIds: intList(m['occasion_ids']),
        seasons: strList(m['seasons']), tagIds: intList(m['tag_ids']), note: (m['note'] as String?) ?? '', photos: strList(m['photos']),
        createdAt: m['created_at'] as int?,
      );
  Map<String, Object?> toMap() => {
        'id': id, 'name': name, 'cover': cover, 'type': type, 'clothes_ids': enc(clothesIds), 'canvas': canvas,
        'occasion_ids': enc(occasionIds), 'seasons': enc(seasons), 'tag_ids': enc(tagIds), 'note': note, 'photos': enc(photos),
        'created_at': createdAt,
      };
}

/// 日历记录：一条 = 一套穿搭 或 一件单品
class CalRecord {
  int? id;
  String date;
  int? outfitId;
  int? clothesId;
  int createdAt;
  CalRecord({this.id, required this.date, this.outfitId, this.clothesId, int? createdAt})
      : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;
  factory CalRecord.fromMap(Map<String, Object?> m) => CalRecord(
      id: m['id'] as int?, date: m['date'] as String, outfitId: m['outfit_id'] as int?, clothesId: m['clothes_id'] as int?,
      createdAt: m['created_at'] as int?);
  Map<String, Object?> toMap() => {'id': id, 'date': date, 'outfit_id': outfitId, 'clothes_id': clothesId, 'created_at': createdAt};
}

class Trip {
  int? id;
  String name;
  String startDate;
  String endDate;
  int createdAt;
  Trip({this.id, required this.name, required this.startDate, required this.endDate, int? createdAt})
      : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;
  factory Trip.fromMap(Map<String, Object?> m) => Trip(
      id: m['id'] as int?, name: m['name'] as String, startDate: m['start_date'] as String, endDate: m['end_date'] as String,
      createdAt: m['created_at'] as int?);
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'start_date': startDate, 'end_date': endDate, 'created_at': createdAt};
}

class TripItem {
  int? id;
  int tripId;
  int clothesId;
  bool manual;
  bool packed;
  TripItem({this.id, required this.tripId, required this.clothesId, this.manual = false, this.packed = false});
  factory TripItem.fromMap(Map<String, Object?> m) => TripItem(
      id: m['id'] as int?, tripId: m['trip_id'] as int, clothesId: m['clothes_id'] as int, manual: m['manual'] == 1, packed: m['packed'] == 1);
  Map<String, Object?> toMap() => {'id': id, 'trip_id': tripId, 'clothes_id': clothesId, 'manual': manual ? 1 : 0, 'packed': packed ? 1 : 0};
}

class TryOnRecord {
  int? id;
  String modelImage;
  String result;
  List<int> clothesIds;
  int createdAt;
  TryOnRecord({this.id, required this.modelImage, required this.result, List<int>? clothesIds, int? createdAt})
      : clothesIds = clothesIds ?? [], createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;
  factory TryOnRecord.fromMap(Map<String, Object?> m) => TryOnRecord(
      id: m['id'] as int?, modelImage: m['model_image'] as String, result: m['result'] as String, clothesIds: intList(m['clothes_ids']),
      createdAt: m['created_at'] as int?);
  Map<String, Object?> toMap() =>
      {'id': id, 'model_image': modelImage, 'result': result, 'clothes_ids': enc(clothesIds), 'created_at': createdAt};
}
