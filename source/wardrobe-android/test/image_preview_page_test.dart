import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wardrobe/pages/image_preview_page.dart';
import 'package:my_wardrobe/services/images.dart';

void main() {
  // AppImage 通过 ImageStore.abs() 拼绝对路径，测试环境没有调用过 init()，
  // 先给 root 一个临时目录，让 AppImage 走 errorBuilder 显示占位（不改业务逻辑）。
  setUpAll(() {
    ImageStore.root = Directory.systemTemp.createTempSync('t214_images_').path;
  });

  testWidgets('ImagePreviewPage 显示 2/3，滑动后显示 3/3', (tester) async {
    // 图片路径不存在，AppImage 会显示占位，不影响计数。
    await tester.pumpWidget(const MaterialApp(
      home: ImagePreviewPage(images: ['no/such/a.jpg', 'no/such/b.jpg', 'no/such/c.jpg'], initial: 1),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2/3'), findsOneWidget);

    // 向左滑动切到下一张
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('2/3'), findsNothing);
  });

  testWidgets('初始为第 1 张显示 1/3，关闭按钮存在', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ImagePreviewPage(images: ['no/such/a.jpg', 'no/such/b.jpg', 'no/such/c.jpg']),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
  });
}
