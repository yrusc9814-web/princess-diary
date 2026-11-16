import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:my_wardrobe/pages/image_edit_page.dart';

/// 双指捏合应缩小裁剪框（整图手势层，不依赖把手）。
Finder _border() => find.byWidgetPredicate((w) =>
    w is Container &&
    w.decoration is BoxDecoration &&
    (w.decoration as BoxDecoration).border is Border &&
    ((w.decoration as BoxDecoration).border as Border).top.color == Colors.white);

Future<void> _openCrop(WidgetTester tester, File f) async {
  await tester.pumpWidget(MaterialApp(home: ImageEditPage(path: f.path)));
  // 文件读取在 isolate 里，转圈动画又让 pumpAndSettle 一直等：真实等待与 pump 交替
  for (var i = 0; i < 100 && find.byType(Image).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(find.byType(Image), findsWidgets);
  await tester.tap(find.byIcon(Icons.crop));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(_border(), findsOneWidget);
}

File _sample() {
  final im = img.Image(width: 200, height: 200);
  img.fill(im, color: img.ColorRgb8(240, 240, 240));
  return File('${Directory.systemTemp.path}/t215_crop_${DateTime.now().microsecondsSinceEpoch}.png')
    ..writeAsBytesSync(img.encodePng(im));
}

void main() {
  testWidgets('裁剪模式双指捏合让框变小', (tester) async {
    final f = _sample();
    addTearDown(() {
      if (f.existsSync()) f.deleteSync();
    });
    await _openCrop(tester, f);

    final border = _border();
    final before = tester.getSize(border);

    final c = tester.getCenter(border);
    final g1 = await tester.startGesture(c - const Offset(40, 0));
    final g2 = await tester.startGesture(c + const Offset(40, 0));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await g1.moveBy(const Offset(5, 0));
      await g2.moveBy(const Offset(-5, 0));
      await tester.pump();
    }
    await g1.up();
    await g2.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final after = tester.getSize(border);
    expect(after.width, lessThan(before.width));
    expect(after.height, lessThan(before.height));
  });

  testWidgets('角把手仍能单独拖动（不被缩放手势层抢走）', (tester) async {
    final f = _sample();
    addTearDown(() {
      if (f.existsSync()) f.deleteSync();
    });
    await _openCrop(tester, f);

    final before = tester.getRect(_border());
    // 4 个把手是仅有的带 onPanUpdate 的 GestureDetector，取最左上那个
    final handles = find.byWidgetPredicate((w) => w is GestureDetector && w.onPanUpdate != null);
    expect(handles, findsNWidgets(4));
    var topLeft = tester.getCenter(handles.first);
    for (final e in handles.evaluate()) {
      final c = tester.getCenter(find.byWidget(e.widget));
      if (c.dx + c.dy < topLeft.dx + topLeft.dy) topLeft = c;
    }
    await tester.dragFrom(topLeft, const Offset(20, 20));
    await tester.pump();

    final after = tester.getRect(_border());
    expect(after.left, greaterThan(before.left));
    expect(after.top, greaterThan(before.top));
    expect(after.right, closeTo(before.right, 0.01));
    expect(after.bottom, closeTo(before.bottom, 0.01));
    expect(after.width, lessThan(before.width));
  });
}
