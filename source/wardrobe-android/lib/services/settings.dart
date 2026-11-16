import 'package:shared_preferences/shared_preferences.dart';

/// 本地设置（SharedPreferences）
class Settings {
  Settings._();
  static late SharedPreferences p;
  static Future<void> init() async => p = await SharedPreferences.getInstance();

  // 个性化
  static bool get showClothesName => p.getBool('show_clothes_name') ?? false;
  static set showClothesName(bool v) => p.setBool('show_clothes_name', v);
  static bool get showOutfitName => p.getBool('show_outfit_name') ?? true;
  static set showOutfitName(bool v) => p.setBool('show_outfit_name', v);
  static bool get remindNewCategory => p.getBool('remind_new_cat') ?? true;
  static set remindNewCategory(bool v) => p.setBool('remind_new_cat', v);
  static bool get batchAutoCutout => p.getBool('batch_auto_cutout') ?? true;
  static set batchAutoCutout(bool v) => p.setBool('batch_auto_cutout', v);
  static bool get autoRecognize => p.getBool('auto_recognize') ?? true;
  static set autoRecognize(bool v) => p.setBool('auto_recognize', v);

  // 自动搭配过滤设置
  /// 形如 "上装" 或 "上装/T恤"
  static List<String> get disabledCats => p.getStringList('disabled_cats') ?? [];
  static set disabledCats(List<String> v) => p.setStringList('disabled_cats', v);
  static List<String> get disabledSlots => p.getStringList('disabled_slots') ?? [];
  static set disabledSlots(List<String> v) => p.setStringList('disabled_slots', v);

  // 单品列表
  static String get groupMode => p.getString('group_mode') ?? 'custom'; // category / color / custom
  static set groupMode(String v) => p.setString('group_mode', v);

  // 天气
  static double? get lat => p.getDouble('lat');
  static double? get lng => p.getDouble('lng');
  static String get cityName => p.getString('city') ?? '';
  static Future<void> setCity(String name, double lat, double lng) async {
    await p.setString('city', name);
    await p.setDouble('lat', lat);
    await p.setDouble('lng', lng);
  }

  // AI 试衣（阿里云百炼）
  static String get dashscopeKey => p.getString('dashscope_key') ?? '';
  static set dashscopeKey(String v) => p.setString('dashscope_key', v.trim());
  /// 旧值迁移：aitryon-plus（效果更好）→ qwen-image-3.0-pro；aitryon 及其他未知值 → qwen-image-3.0。
  static String get tryOnModel {
    final v = p.getString('tryon_model');
    switch (v) {
      case 'qwen-image-3.0':
      case 'qwen-image-3.0-pro':
        return v!;
      case 'aitryon-plus':
        return 'qwen-image-3.0-pro';
      default:
        return 'qwen-image-3.0';
    }
  }
  static set tryOnModel(String v) => p.setString('tryon_model', v);

  // 备份
  static int get lastExport => p.getInt('last_export') ?? 0;
  static set lastExport(int v) => p.setInt('last_export', v);

  // 自动备份（每天凌晨 3 点）
  static bool get autoBackupEnabled => p.getBool('auto_backup_enabled') ?? true;
  static set autoBackupEnabled(bool v) => p.setBool('auto_backup_enabled', v);
  /// 上次自动备份成功时的数据指纹（sha256）
  static String get autoBackupHash => p.getString('auto_backup_hash') ?? '';
  static set autoBackupHash(String v) => p.setString('auto_backup_hash', v);
  /// 上次自动备份成功的时间（毫秒）
  static int get autoBackupAt => p.getInt('auto_backup_at') ?? 0;
  static set autoBackupAt(int v) => p.setInt('auto_backup_at', v);
  /// 上次自动备份成功的文件名
  static String get autoBackupFile => p.getString('auto_backup_file') ?? '';
  static set autoBackupFile(String v) => p.setString('auto_backup_file', v);
  /// 上次自动备份「检查」的时间（毫秒），无变化跳过时也会更新
  static int get autoBackupLastCheck => p.getInt('auto_backup_last_check') ?? 0;
  static set autoBackupLastCheck(int v) => p.setInt('auto_backup_last_check', v);
  /// 上次自动备份失败原因（空串表示无）
  static String get autoBackupError => p.getString('auto_backup_error') ?? '';
  static set autoBackupError(String v) => p.setString('auto_backup_error', v);

  // 首页
  static String get recordedToday => p.getString('recorded_today') ?? '';
  static set recordedToday(String v) => p.setString('recorded_today', v);
  static int get recommendSeed => p.getInt('rec_seed') ?? 0;
  static set recommendSeed(int v) => p.setInt('rec_seed', v);
}
