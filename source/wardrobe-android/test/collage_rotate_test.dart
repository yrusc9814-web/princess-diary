import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_wardrobe/pages/collage_page.dart';

/// 拼图元素旋转后拖动方向的换算。
/// (10,0) 是「旋转后局部坐标」里的位移，rotateDelta 要把它换回屏幕坐标：
/// 屏幕位移 = R(rot) * 局部位移，即 sx = dx·cos(rot) - dy·sin(rot)、sy = dx·sin(rot) + dy·cos(rot)。
void main() {
  const d = Offset(10, 0);
  const eps = 1e-6;

  void expectOffset(Offset a, Offset b) {
    expect((a.dx - b.dx).abs(), lessThan(eps), reason: 'dx ${a.dx} vs ${b.dx}');
    expect((a.dy - b.dy).abs(), lessThan(eps), reason: 'dy ${a.dy} vs ${b.dy}');
  }

  test('rot = 0：方向不变', () {
    expectOffset(rotateDelta(d, 0), const Offset(10, 0));
  });

  test('rot = π/2：局部向右 = 屏幕向下', () {
    expectOffset(rotateDelta(d, math.pi / 2), const Offset(0, 10));
  });

  test('rot = π：左右上下全反', () {
    expectOffset(rotateDelta(d, math.pi), const Offset(-10, 0));
  });

  test('rot = 2π 等价于 0', () {
    expectOffset(rotateDelta(d, 2 * math.pi), const Offset(10, 0));
  });

  test('rot = -π/2：局部向右 = 屏幕向上', () {
    expectOffset(rotateDelta(d, -math.pi / 2), const Offset(0, -10));
  });

  test('任意角度长度不变', () {
    for (final r in [0.3, 1.1, -2.2, 3.0]) {
      final o = rotateDelta(const Offset(3, -4), r);
      expect((o.distance - 5).abs(), lessThan(eps));
    }
  });
}
