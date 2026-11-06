// 2.1.0 粉色主题截图：flutter test test/screens_test.dart --update-goldens
// 仅用于开发时目测，不参与打包。需要 /tmp/shot_fonts 下的 NotoSansSC 字体（脚本 work/theme 下载）。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wardrobe/data/db.dart';
import 'package:my_wardrobe/data/models.dart';
import 'package:my_wardrobe/main.dart';
import 'package:my_wardrobe/pages/backup_page.dart';
import 'package:my_wardrobe/pages/material_page.dart';
import 'package:my_wardrobe/pages/stats_page.dart';
import 'package:my_wardrobe/pages/trips_page.dart';
import 'package:my_wardrobe/pages/tryon_page.dart';
import 'package:my_wardrobe/pages/flip_page.dart';
import 'package:my_wardrobe/pages/settings_page.dart';
import 'package:my_wardrobe/pages/wardrobe_page.dart';
import 'package:my_wardrobe/pages/home_page.dart';
import 'package:my_wardrobe/services/images.dart';
import 'package:my_wardrobe/services/settings.dart';
import 'package:my_wardrobe/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.view(Uint8List.fromList(File(f).readAsBytesSync()).buffer)));
  }
  await l.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tmp = Directory.systemTemp.createTempSync('shots');

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (c) async => tmp.path);
    SharedPreferences.setMockInitialValues({});
    const fonts = '/tmp/shot_fonts';
    // 所有中文走 NotoSansSC，图标走 MaterialIcons
    for (final fam in ['Roboto', 'sans-serif', 'Noto Sans CJK SC', 'Noto Sans SC', 'NotoSansCJK', '.SF UI Text', '.AppleSystemUIFont', 'Source Han Sans', 'PingFang SC', 'Heiti SC', 'Microsoft YaHei', 'MiSans', 'HarmonyOS Sans SC']) {
      await _loadFont(fam, ['$fonts/NotoSansSC-Regular.otf', '$fonts/NotoSansSC-Bold.otf']);
    }
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    await Settings.init();
    await ImageStore.init();
    await AppDb.I.open();
  });

  Future<void> shot(WidgetTester t, Widget page, String name, {bool shell = false, int tab = 0, int clothes = 0}) async {
    t.view.physicalSize = const Size(1080, 2280);
    t.view.devicePixelRatio = 2.625;
    Shell.tab.value = tab;
    await t.pumpWidget(shell ? const WardrobeApp() : WardrobeAppForTest(page));
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(milliseconds: 100));
    }
    // 预加载可见图片
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        final img = e.widget as Image;
        await precacheImage(img.image, e);
      }
    });
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('home', (t) async => shot(t, const SizedBox(), '1_home', shell: true, tab: 0));
  testWidgets('wardrobe_empty', (t) async => shot(t, const SizedBox(), '2_wardrobe_empty', shell: true, tab: 1));
  testWidgets('outfits_empty', (t) async => shot(t, const SizedBox(), '3_outfits_empty', shell: true, tab: 2));
  testWidgets('calendar', (t) async => shot(t, const SizedBox(), '4_calendar', shell: true, tab: 3));
  testWidgets('mine', (t) async => shot(t, const SizedBox(), '5_mine', shell: true, tab: 4));
  testWidgets('stats', (t) async => shot(t, const StatsPage(), '6_stats'));
  testWidgets('trips', (t) async => shot(t, const TripsPage(), '7_trips'));
  testWidgets('material', (t) async => shot(t, const MaterialLibraryPage(), '8_material'));
  testWidgets('tryon', (t) async => shot(t, const TryOnPage(), '9_tryon'));
  testWidgets('backup', (t) async => shot(t, const BackupPage(), '10_backup'));
  testWidgets('settings', (t) async => shot(t, const SettingsPage(), '11_settings'));
  testWidgets('flip', (t) async => shot(t, const FlipPage(), '12_flip'));
  Future<void> overlay(WidgetTester t, String name, void Function(BuildContext) open) async {
    t.view.physicalSize = const Size(1080, 2280);
    t.view.devicePixelRatio = 2.625;
    await t.pumpWidget(const WardrobeAppForTest(Scaffold(body: SizedBox.expand())));
    await t.pump();
    open(navKey.currentContext!);
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await t.pump(const Duration(milliseconds: 300));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('sheet_add', (t) async => overlay(t, '14_sheet_add', (c) => showAddClothesSheet(c)));
  testWidgets('dialog_confirm', (t) async => overlay(t, '15_dialog', (c) => confirm(c, '删除记录', '确定删除这条穿搭记录？', danger: true)));
  testWidgets('dialog_input', (t) async => overlay(t, '16_input', (c) => inputDialog(c, '手动设置城市', hint: '定位失败时使用，如：厦门')));
  testWidgets('weather_sheet', (t) async => overlay(t, '17_weather', (c) => showWeatherSheet(c)));
  testWidgets('toast_dark', (t) async => overlay(t, '18_toast', (c) => toast(c, '已记录到今天', style: 'dark')));

  testWidgets('with_data', (t) async {
    await t.runAsync(() async {
      final src = File('${tmp.path}/images/sample.png');
      src.writeAsBytesSync(File('assets/illustrations/ov_tshirt.png').readAsBytesSync());
      await AppDb.I.saveClothes(Clothes(name: '粉色T恤', image: 'sample.png', thumb: 'sample.png', cat1: '上装', status: '拥有'));
      dataVersion.value++;
    });
    await shot(t, const SizedBox(), '13_wardrobe_data', shell: true, tab: 1);
  });
}

/// 用正式主题包住单个页面
class WardrobeAppForTest extends StatelessWidget {
  final Widget page;
  const WardrobeAppForTest(this.page, {super.key});
  @override
  Widget build(BuildContext context) {
    final app = const WardrobeApp().build(context) as MaterialApp;
    return MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: app.theme,
      locale: app.locale,
      supportedLocales: app.supportedLocales,
      localizationsDelegates: app.localizationsDelegates,
      home: page,
    );
  }
}
