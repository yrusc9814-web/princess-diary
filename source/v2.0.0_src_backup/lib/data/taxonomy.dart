import 'package:flutter/material.dart';

/// 系统衣物品类（两级，固定）。一级名 -> 二级名列表
const Map<String, List<String>> sysCategories = {
  '上装': ['T恤', '衬衫', 'POLO衫', '卫衣', '毛衣/针织衫', '背心/吊带', '打底衫'],
  '下装': ['牛仔裤', '休闲裤', '西裤', '运动裤', '短裤', '半身裙', '打底裤'],
  '连衣裙': ['连衣裙', '吊带裙', '衬衫裙', '针织裙'],
  '连体装': ['连体裤', '背带裤', '套装'],
  '外套': ['夹克', '西装', '风衣', '大衣', '羽绒服', '棉服', '开衫', '皮衣', '马甲', '冲锋衣'],
  '鞋履': ['运动鞋', '板鞋', '帆布鞋', '皮鞋', '靴子', '高跟鞋', '凉鞋/拖鞋'],
  '包袋': ['双肩包', '单肩包/斜挎包', '手提包', '钱包/卡包'],
  '配饰': ['帽子', '围巾', '手套', '腰带', '领带/领结', '首饰', '眼镜', '袜子', '其他配饰'],
  '内衣/家居服': ['内衣', '睡衣/家居服', '泳衣'],
  '其他': ['其他'],
};

const unrecognized = '未识别';
const noSysCat = '未设置衣物品类';

/// 翻牌 / 搭配位 品类（slot key -> 显示名）。
const flipSlots = [
  '外套', '上装', '下装', '连衣裙/连体装', '鞋履', '包袋', '围巾', '帽子', '手套', '腰带', '领带/领结', '首饰', '其他配饰', '内衣/家居服', '其他', '未识别',
];

/// 某件衣物属于哪个翻牌槽位
String flipSlotOf(String? c1, String? c2) {
  if (c1 == null || c1.isEmpty) return '未识别';
  if (c1 == '连衣裙' || c1 == '连体装') return '连衣裙/连体装';
  if (c1 == '配饰') {
    if (c2 == null || c2.isEmpty) return '其他配饰';
    if (const ['围巾', '帽子', '手套', '腰带', '领带/领结', '首饰'].contains(c2)) return c2;
    return '其他配饰';
  }
  if (flipSlots.contains(c1)) return c1;
  return '其他';
}

/// 自动搭配 "搭配位"
const disableSlotOptions = ['内搭层', '上装外搭来源', '系统外套来源', '包袋', '配饰'];

const statusOptions = ['拥有', '种草', '素材', '丢弃'];
const seasonOptions = ['春季', '夏季', '秋季', '冬季'];
const seasonShort = {'春季': '春', '夏季': '夏', '秋季': '秋', '冬季': '冬'};
const styleOptions = ['休闲', '通勤', '运动', '街头', '复古', '甜美', '极简', '正式', '优雅', '学院'];
const materialOptions = ['棉', '羊毛', '羽绒', '皮革', '牛仔', '针织', '亚麻', '丝绸', '雪纺', '羊绒', '涤纶', '灯芯绒', '麂皮', '尼龙'];
const warmthOptions = ['薄', '适中', '保暖', '很保暖'];
const silhouetteOptions = ['修身', '合身', '宽松', '廓形'];
const lengthOptions = ['短', '常规', '长', '超长'];
const layerOptions = ['打底', '中间层', '外层'];

class ColorOpt {
  final String name;
  final Color color;
  const ColorOpt(this.name, this.color);
}

const colorOptions = [
  ColorOpt('黑色', Color(0xFF1F1F1F)),
  ColorOpt('白色', Color(0xFFFFFFFF)),
  ColorOpt('米色', Color(0xFFEFE3CC)),
  ColorOpt('灰色', Color(0xFF9E9E9E)),
  ColorOpt('红色', Color(0xFFE53935)),
  ColorOpt('橙色', Color(0xFFFB8C00)),
  ColorOpt('黄色', Color(0xFFFDD835)),
  ColorOpt('绿色', Color(0xFF43A047)),
  ColorOpt('青色', Color(0xFF26C6DA)),
  ColorOpt('蓝色', Color(0xFF1E88E5)),
  ColorOpt('紫色', Color(0xFF8E24AA)),
  ColorOpt('粉色', Color(0xFFF48FB1)),
  ColorOpt('卡其色', Color(0xFFC3B091)),
  ColorOpt('棕色', Color(0xFF795548)),
  ColorOpt('藏青色', Color(0xFF1A237E)),
  ColorOpt('金色', Color(0xFFD4AF37)),
  ColorOpt('银色', Color(0xFFC0C0C0)),
  ColorOpt('多色', Color(0xFFFF80AB)),
];

Color colorOf(String name) {
  for (final c in colorOptions) {
    if (c.name == name) return c.color;
  }
  return Colors.grey;
}

bool isNeutralColor(String name) => const ['黑色', '白色', '米色', '灰色', '卡其色', '棕色', '藏青色', '银色'].contains(name);

const colorHue = {'红色': 0, '橙色': 30, '黄色': 55, '金色': 48, '绿色': 120, '青色': 185, '蓝色': 215, '紫色': 280, '粉色': 330};

/// 内置常见品牌（拼音/字母排序显示）
const builtinBrands = [
  'Adidas 阿迪达斯', 'Arc\'teryx 始祖鸟', 'Balenciaga 巴黎世家', 'Bananain 蕉内', 'Bershka', 'Burberry 博柏利', 'Calvin Klein', 'Canada Goose 加拿大鹅',
  'Champion', 'Chanel 香奈儿', 'Coach 蔻驰', 'Columbia 哥伦比亚', 'Converse 匡威', 'COS', 'Dior 迪奥', 'Fila 斐乐', 'Gap', 'Gucci 古驰', 'H&M',
  'Hermès 爱马仕', 'Jack&Jones 杰克琼斯', 'Lacoste 鳄鱼', 'Levi\'s 李维斯', 'Lining 李宁', 'Louis Vuitton 路易威登', 'Lululemon', 'Mango', 'MaxMara',
  'MLB', 'Moncler 盟可睐', 'Muji 无印良品', 'New Balance 新百伦', 'Nike 耐克', 'North Face 北面', 'Only', 'Prada 普拉达', 'Puma 彪马', 'Ralph Lauren 拉夫劳伦',
  'Salomon 萨洛蒙', 'Skechers 斯凯奇', 'Supreme', 'Tommy Hilfiger', 'UGG', 'Under Armour 安德玛', 'Uniqlo 优衣库', 'Vans 范斯', 'Vero Moda', 'Zara',
  '安踏', '波司登', '拉夏贝尔', '太平鸟', '海澜之家', '森马', '美特斯邦威', '班尼路', '江南布衣', '例外', '之禾', '鄂尔多斯', '特步', '361°', '鸿星尔克',
  '回力', '骆驼', '红蜻蜓', '百丽', '达芙妮', 'Ubras', '内外', '蕉下', '茵曼', '裂帛', 'MO&Co.', 'URBAN REVIVO', 'Bosie', '李宁中国', '无品牌',
];

/// 本地模型（tag_embeddings.json）里的二级品类 key -> (一级, 二级)
const taggerCategoryMap = {
  'T恤': ['上装', 'T恤'], '衬衫': ['上装', '衬衫'], '卫衣': ['上装', '卫衣'], '毛衣/针织': ['上装', '毛衣/针织衫'], '背心/吊带': ['上装', '背心/吊带'],
  'Polo': ['上装', 'POLO衫'], '牛仔裤': ['下装', '牛仔裤'], '休闲裤': ['下装', '休闲裤'], '运动裤': ['下装', '运动裤'], '短裤': ['下装', '短裤'],
  '半身裙': ['下装', '半身裙'], '连衣裙': ['连衣裙', '连衣裙'], '连体裤': ['连体装', '连体裤'], '夹克': ['外套', '夹克'], '西装': ['外套', '西装'],
  '风衣': ['外套', '风衣'], '大衣': ['外套', '大衣'], '羽绒服': ['外套', '羽绒服'], '开衫': ['外套', '开衫'], '运动鞋': ['鞋履', '运动鞋'],
  '皮鞋': ['鞋履', '皮鞋'], '靴子': ['鞋履', '靴子'], '凉鞋/拖鞋': ['鞋履', '凉鞋/拖鞋'], '双肩包': ['包袋', '双肩包'], '单肩/斜挎': ['包袋', '单肩包/斜挎包'],
  '手提包': ['包袋', '手提包'], '帽子': ['配饰', '帽子'], '围巾': ['配饰', '围巾'], '腰带': ['配饰', '腰带'], '首饰': ['配饰', '首饰'], '手套': ['配饰', '手套'],
};

const taggerColorMap = {
  'black': '黑色', 'white': '白色', 'gray': '灰色', 'beige': '米色', 'brown': '棕色', 'red': '红色', 'pink': '粉色', 'orange': '橙色',
  'yellow': '黄色', 'green': '绿色', 'blue': '蓝色', 'purple': '紫色',
};
const taggerWarmthMap = {'thin': '薄', 'medium': '适中', 'warm': '保暖', 'very_warm': '很保暖'};
const taggerFitMap = {'slim': '修身', 'regular': '合身', 'loose': '宽松'};
const taggerLengthMap = {'short': '短', 'regular': '常规', 'long': '长', 'extra_long': '超长'};
const taggerLayerMap = {'base': '打底', 'mid': '中间层', 'outer': '外层'};
const taggerStyleMap = {
  'casual': '休闲', 'commute': '通勤', 'sport': '运动', 'street': '街头', 'minimal': '极简', 'vintage': '复古', 'sweet': '甜美', 'formal': '正式',
};
const taggerSeasonMap = {'spring': '春季', 'summer': '夏季', 'autumn': '秋季', 'winter': '冬季'};
const taggerMaterialMap = {
  '棉': '棉', '麻': '亚麻', '羊毛': '羊毛', '羊绒': '羊绒', '羽绒': '羽绒', '皮革': '皮革', '麂皮': '麂皮', '牛仔': '牛仔', '丝绸': '丝绸',
  '雪纺': '雪纺', '针织': '针织', '化纤': '涤纶', '灯芯绒': '灯芯绒',
};

/// 默认场合
const defaultOccasions = ['工作', '休闲', '约会', '运动', '旅行', '聚会'];
