import 'package:flutter_test/flutter_test.dart';
import 'package:my_wardrobe/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 旧值 → 新模型的迁移。原 aitryon / aitryon-plus 已下架（2026-11）。
Future<String> _modelWith(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  await Settings.init();
  return Settings.tryOnModel;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('旧值 aitryon → qwen-image-3.0', () async {
    expect(await _modelWith({'tryon_model': 'aitryon'}), 'qwen-image-3.0');
  });

  test('旧值 aitryon-plus → qwen-image-3.0-pro', () async {
    expect(await _modelWith({'tryon_model': 'aitryon-plus'}), 'qwen-image-3.0-pro');
  });

  test('空值（首次启动）→ qwen-image-3.0', () async {
    expect(await _modelWith({}), 'qwen-image-3.0');
  });

  test('未知值 → qwen-image-3.0', () async {
    expect(await _modelWith({'tryon_model': 'some-other-model'}), 'qwen-image-3.0');
  });

  test('已经是新值则原样返回', () async {
    expect(await _modelWith({'tryon_model': 'qwen-image-3.0'}), 'qwen-image-3.0');
    expect(await _modelWith({'tryon_model': 'qwen-image-3.0-pro'}), 'qwen-image-3.0-pro');
  });
}
