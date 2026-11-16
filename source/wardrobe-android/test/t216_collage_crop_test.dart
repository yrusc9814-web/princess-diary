import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:my_wardrobe/pages/collage_page.dart';
import 'package:my_wardrobe/pages/image_edit_page.dart';
import 'package:my_wardrobe/services/images.dart';

/// T216：拼图里的照片要用户主动点「裁剪」才进裁剪页。
/// - _El 的 original 字段（JSON 键 'o'）带/不带都要能往返；
/// - 底部工具栏只在选中照片时出现「裁剪」，单品/文字/未选中都不出现。

String _canvas(List<Map<String, dynamic>> els) => jsonEncode({'els': els, 'bg': [0xFFFFFFFF], 'bgImage': null});

Map<String, dynamic> _photo({String? original}) => {
      'k': 'photo',
      'i': 'img_cropped.jpg',
      'c': null,
      't': '',
      'col': 0xFF000000,
      'x': 0.4,
      'y': 0.6,
      's': 1.5,
      'r': 0.25,
      if (original != null) 'o': original,
    };

Map<String, dynamic> _clothes() => {'k': 'clothes', 'i': 'cloth.jpg', 'c': 7, 't': '', 'col': 0xFF000000, 'x': 0.3, 'y': 0.3, 's': 1, 'r': 0};

Map<String, dynamic> _text() => {'k': 'text', 'i': null, 'c': null, 't': '你好', 'col': 0xFF000000, 'x': 0.5, 'y': 0.5, 's': 1, 'r': 0};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('_El 的 original 字段 JSON 往返', () {
    test('带 \'o\'：裁剪后的照片能记住原图', () {
      final out = jsonDecode(collageJsonRoundTrip(_canvas([_photo(original: 'orig_a.jpg')]))) as Map<String, dynamic>;
      final el = (out['els'] as List).first as Map<String, dynamic>;
      expect(el['o'], 'orig_a.jpg');
      expect(el['i'], 'img_cropped.jpg');
      // 其余字段不受影响
      expect(el['x'], 0.4);
      expect(el['y'], 0.6);
      expect(el['s'], 1.5);
      expect(el['r'], 0.25);
    });

    test('不带 \'o\' 的旧数据：解析不报错，original 为空', () {
      final out = jsonDecode(collageJsonRoundTrip(_canvas([_photo()]))) as Map<String, dynamic>;
      final el = (out['els'] as List).first as Map<String, dynamic>;
      expect(el.containsKey('o'), isTrue);
      expect(el['o'], isNull);
      expect(el['i'], 'img_cropped.jpg');
    });

    test('旧数据里 \'o\' 显式为 null 也能读', () {
      final el = _photo()..['o'] = null;
      final out = jsonDecode(collageJsonRoundTrip(_canvas([el]))) as Map<String, dynamic>;
      expect(((out['els'] as List).first as Map<String, dynamic>)['o'], isNull);
    });
  });

  group('工具栏「裁剪」按钮的出现条件', () {
    late Directory root;

    setUp(() async {
      // AppImage 会按相对路径读本地文件，指到临时目录避免读真实相册目录。
      root = await Directory.systemTemp.createTemp('t216_images');
      ImageStore.root = root.path;
      File('${root.path}/img_cropped.jpg').writeAsBytesSync(_onePixelPng);
      File('${root.path}/cloth.jpg').writeAsBytesSync(_onePixelPng);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> els) async {
      await tester.pumpWidget(MaterialApp(home: CollagePage(canvasJson: _canvas(els))));
      await tester.pumpAndSettle();
    }

    Future<void> tapElement(WidgetTester tester, Type widgetType, {int index = 0}) async {
      final f = find.byType(widgetType);
      expect(f, findsWidgets);
      await tester.tap(f.at(index));
      await tester.pumpAndSettle();
    }

    testWidgets('未选中任何元素：5 个工具，没有「裁剪」', (tester) async {
      await open(tester, [_photo()]);
      expect(find.byIcon(Icons.crop), findsNothing);
      expect(find.text('裁剪'), findsNothing);
      // 单品/照片/文字/背景/更多
      expect(find.text('更多'), findsOneWidget);
    });

    testWidgets('选中照片：多出「裁剪」', (tester) async {
      await open(tester, [_photo()]);
      await tapElement(tester, Image);
      expect(find.byIcon(Icons.crop), findsOneWidget);
      expect(find.text('裁剪'), findsOneWidget);
      // 原有工具都还在
      expect(find.text('单品'), findsOneWidget);
      expect(find.text('照片'), findsOneWidget);
      expect(find.text('文字'), findsOneWidget);
      expect(find.text('背景'), findsOneWidget);
      expect(find.text('更多'), findsOneWidget);
    });

    testWidgets('选中单品：没有「裁剪」', (tester) async {
      await open(tester, [_clothes()]);
      await tapElement(tester, Image);
      expect(find.byIcon(Icons.crop), findsNothing);
      expect(find.text('裁剪'), findsNothing);
    });

    testWidgets('选中文字：没有「裁剪」', (tester) async {
      await open(tester, [_text()]);
      await tapElement(tester, Text);
      expect(find.byIcon(Icons.crop), findsNothing);
      expect(find.text('裁剪'), findsNothing);
    });

    testWidgets('选中照片→再点空白取消选中：「裁剪」消失', (tester) async {
      await open(tester, [_photo()]);
      await tapElement(tester, Image);
      expect(find.text('裁剪'), findsOneWidget);
      // 画布最外层 GestureDetector（child 是 RepaintBoundary）的 onTap 会清掉选中；
      // 点它左上角，避开居中偏下的照片元素。
      final canvas = find.byWidgetPredicate((w) => w is GestureDetector && w.onTap != null && w.child is RepaintBoundary);
      expect(canvas, findsOneWidget);
      final r = tester.getRect(canvas);
      await tester.tapAt(r.topLeft + const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text('裁剪'), findsNothing);
    });
  });

  group('裁剪入口', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('t216_crop_entry');
      ImageStore.root = root.path;
      File('${root.path}/img_cropped.jpg').writeAsBytesSync(_onePixelPng);
      File('${root.path}/orig_a.jpg').writeAsBytesSync(_onePixelPng);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> els) async {
      await tester.pumpWidget(MaterialApp(home: CollagePage(canvasJson: _canvas(els))));
      await tester.pumpAndSettle();
    }

    testWidgets('cropOnly 的编辑页一进来就是裁剪模式（不用再点一次裁剪）', (tester) async {
      final sample = File('${root.path}/sample.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 120, height: 120)..clear(img.ColorRgb8(240, 240, 240))));
      await tester.pumpWidget(MaterialApp(home: ImageEditPage(path: sample.path, cropOnly: true)));
      for (var i = 0; i < 100 && find.byType(Image).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(find.byType(Image), findsWidgets);
      // 裁剪框白边框直接出现，说明已经是裁剪模式；底部是「取消/全图/完成裁剪」，没有「下一步」
      final border = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).border is Border &&
          ((w.decoration as BoxDecoration).border as Border).top.color == Colors.white);
      expect(border, findsOneWidget);
      expect(find.text('下一步'), findsNothing);
      expect(find.text('全图'), findsOneWidget);
    });

    testWidgets('点「裁剪」进裁剪页，原图传的是 original 而不是裁过的图', (tester) async {
      await open(tester, [_photo(original: 'orig_a.jpg')]);
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.text('裁剪'), findsOneWidget);

      await tester.tap(find.text('裁剪'));
      // 只推一帧：图片解码在 isolate 里，等它反而会一直转圈
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final page = tester.widget<ImageEditPage>(find.byType(ImageEditPage));
      expect(page.cropOnly, isTrue, reason: '拼图裁剪要直接进裁剪模式');
      expect(page.path, ImageStore.abs('orig_a.jpg'), reason: '再次裁剪要回到完整原图');
    });
  });
}

/// 1x1 透明 PNG，Image.file 能正常解码，避免 errorBuilder 干扰点击。
final _onePixelPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
