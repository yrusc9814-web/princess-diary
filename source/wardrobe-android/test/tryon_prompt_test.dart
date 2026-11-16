import 'package:flutter_test/flutter_test.dart';
import 'package:my_wardrobe/services/tryon.dart';

void main() {
  group('TryOn.prompt 指令里图号', () {
    test('只有上衣：图2 是上衣', () {
      final p = TryOn.prompt(hasTop: true, hasBottom: false);
      expect(p, contains('图2中的上衣'));
      expect(p, isNot(contains('下装')));
      expect(p, isNot(contains('图3')));
    });

    test('只有下装：图2 是下装', () {
      final p = TryOn.prompt(hasTop: false, hasBottom: true);
      expect(p, contains('图2中的下装'));
      expect(p, isNot(contains('图3')));
      expect(p, isNot(contains('上衣')));
    });

    test('上下都有：图2 上衣、图3 下装', () {
      final p = TryOn.prompt(hasTop: true, hasBottom: true);
      expect(p, contains('图2中的上衣'));
      expect(p, contains('图3中的下装'));
    });

    test('连衣裙提示与固定尾巴都在', () {
      final p = TryOn.prompt(hasTop: true, hasBottom: true);
      expect(p, contains('如果是连衣裙就整件穿上'));
      expect(p, contains('严格保持图1人物的脸、发型、体型、姿势、背景和光线完全不变'));
      expect(p, contains('真实照片质感'));
    });
  });

  test('模型列表只有千问图像编辑两档', () {
    expect(TryOn.models.keys, ['qwen-image-3.0', 'qwen-image-3.0-pro']);
  });
}
