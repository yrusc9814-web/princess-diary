import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_wardrobe/utils/crop_math.dart';

void main() {
  const center = Offset(0.5, 0.5);

  test('scale=1 且无平移时裁剪框不变', () {
    const base = Rect.fromLTWH(0.2, 0.3, 0.4, 0.5);
    expect(scaleCrop(base, 1, center, Offset.zero), base);
  });

  test('scale=2 以中心放大，并夹在 [0,1]', () {
    const base = Rect.fromLTRB(0.3, 0.3, 0.7, 0.7);
    final r = scaleCrop(base, 2, center, Offset.zero);
    expect(r.width, closeTo(0.8, 1e-9));
    expect(r.height, closeTo(0.8, 1e-9));
    expect(r.center.dx, closeTo(0.5, 1e-9));
    expect(r.center.dy, closeTo(0.5, 1e-9));
    // 放大到超出边界时整体夹住，不越界也不压扁。
    final big = scaleCrop(const Rect.fromLTRB(0.4, 0.4, 0.6, 0.6), 8, center, Offset.zero);
    expect(big.left, greaterThanOrEqualTo(0.0));
    expect(big.top, greaterThanOrEqualTo(0.0));
    expect(big.right, lessThanOrEqualTo(1.0));
    expect(big.bottom, lessThanOrEqualTo(1.0));
    expect(big.width, closeTo(big.height, 1e-9));
  });

  test('scale=0.1 时宽高都不小于 0.08', () {
    const base = Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);
    final r = scaleCrop(base, 0.1, center, Offset.zero);
    expect(r.width, greaterThanOrEqualTo(0.08 - 1e-9));
    expect(r.height, greaterThanOrEqualTo(0.08 - 1e-9));
    expect(r.width, closeTo(0.08, 1e-9));
    expect(r.height, closeTo(0.08, 1e-9));
  });

  test('焦点在左上角时缩小，左上角不动', () {
    const base = Rect.fromLTRB(0.0, 0.0, 0.6, 0.6);
    final r = scaleCrop(base, 0.5, Offset.zero, Offset.zero);
    expect(r.width, lessThan(base.width));
    expect(r.left, closeTo(0.0, 1e-9));
    expect(r.top, closeTo(0.0, 1e-9));
  });

  test('平移越界被夹回且尺寸不变', () {
    const c = Rect.fromLTWH(0.2, 0.2, 0.3, 0.4);
    final far = panCrop(c, const Offset(5, -5));
    expect(far.width, closeTo(0.3, 1e-9));
    expect(far.height, closeTo(0.4, 1e-9));
    expect(far.left, closeTo(0.7, 1e-9));
    expect(far.top, closeTo(0.0, 1e-9));
  });

  test('缩放同时跟随焦点平移', () {
    const base = Rect.fromLTRB(0.25, 0.25, 0.75, 0.75);
    final r = scaleCrop(base, 1, center, const Offset(0.1, 0));
    expect(r.width, closeTo(0.5, 1e-9));
    expect(r.left, closeTo(0.35, 1e-9));
  });
}
