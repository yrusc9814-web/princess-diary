import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/db.dart';
import 'pages/calendar_page.dart';
import 'pages/home_page.dart';
import 'pages/mine_page.dart';
import 'pages/outfits_page.dart';
import 'pages/wardrobe_page.dart';
import 'services/images.dart';
import 'services/settings.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.init();
  await ImageStore.init();
  await AppDb.I.open();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, systemNavigationBarColor: Colors.white, systemNavigationBarIconBrightness: Brightness.dark));
  runApp(const WardrobeApp());
}

class WardrobeApp extends StatelessWidget {
  const WardrobeApp({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: kRose, brightness: Brightness.light).copyWith(
      primary: kRose,
      onPrimary: Colors.white,
      primaryContainer: kRoseLight,
      onPrimaryContainer: kRoseDark,
      secondary: kRose,
      onSecondary: Colors.white,
      secondaryContainer: kRoseLight,
      onSecondaryContainer: kRoseDark,
      tertiary: const Color(0xFFF08A9F),
      tertiaryContainer: kRoseBg,
      onTertiaryContainer: kRoseDark,
      surface: Colors.white,
      onSurface: kInk,
      onSurfaceVariant: const Color(0xFF6E6468),
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFFF8FA),
      surfaceContainer: const Color(0xFFFFF3F6),
      surfaceContainerHigh: const Color(0xFFFDEDF1),
      surfaceContainerHighest: const Color(0xFFFBE5EB),
      outline: const Color(0xFFE9C3CE),
      outlineVariant: kPinkLine,
      shadow: const Color(0xFFE8A0B4),
      inversePrimary: kRoseSoft,
      error: const Color(0xFFE53950),
    );
    return MaterialApp(
      title: '公主日记',
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        // 每个页面由 PinkPageTransitions 铺淡粉渐变底，Scaffold 透明
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: kSheetBg,
        splashColor: kRoseLight,
        highlightColor: kRoseBg,
        dividerColor: kPinkLine,
        dividerTheme: const DividerThemeData(color: kPinkLine, space: 1, thickness: 1),
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: PinkPageTransitions(),
          TargetPlatform.iOS: PinkPageTransitions(),
          TargetPlatform.linux: PinkPageTransitions(),
          TargetPlatform.macOS: PinkPageTransitions(),
          TargetPlatform.windows: PinkPageTransitions(),
          TargetPlatform.fuchsia: PinkPageTransitions(),
        }),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: kInk,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          iconTheme: IconThemeData(color: kInk),
          actionsIconTheme: IconThemeData(color: kInk),
          titleTextStyle: TextStyle(fontSize: 20, color: kInk, fontWeight: FontWeight.w700),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xF7FFFFFF),
          surfaceTintColor: Colors.transparent,
          indicatorColor: kRoseLight,
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
          height: 66,
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? kRose : const Color(0xFF6E6468), size: 25)),
          labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12, color: s.contains(WidgetState.selected) ? kRose : const Color(0xFF6E6468), fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: kRoseLight,
          foregroundColor: kRose,
          elevation: 4,
          focusElevation: 4,
          hoverElevation: 5,
          highlightElevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          iconSize: 30,
          sizeConstraints: const BoxConstraints.tightFor(width: 64, height: 64),
        ),
        dialogTheme: DialogThemeData(
          barrierColor: const Color(0x663A1F2A),
          backgroundColor: kSheetBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          titleTextStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: kInk),
        ),
        bottomSheetTheme: const BottomSheetThemeData(modalBarrierColor: Color(0x663A1F2A), backgroundColor: kSheetBg, surfaceTintColor: Colors.transparent, dragHandleColor: Color(0xFFF3C9D4)),
        popupMenuTheme: PopupMenuThemeData(color: kSheetBg, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        menuTheme: const MenuThemeData(style: MenuStyle(backgroundColor: WidgetStatePropertyAll(kSheetBg), surfaceTintColor: WidgetStatePropertyAll(Colors.transparent))),
        cardTheme: CardThemeData(color: kCardColor, surfaceTintColor: Colors.transparent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
        listTileTheme: const ListTileThemeData(iconColor: kRose, selectedColor: kRose, selectedTileColor: kRoseBg),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kRose, textStyle: const TextStyle(fontWeight: FontWeight.w600))),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: kRose, foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFF6D5DE), disabledForegroundColor: Colors.white)),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kRose, surfaceTintColor: Colors.transparent, shadowColor: const Color(0x33E8456B))),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: kRose, side: const BorderSide(color: kPinkBorder))),
        iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(highlightColor: kRoseLight)),
        segmentedButtonTheme: SegmentedButtonThemeData(style: SegmentedButton.styleFrom(
          selectedBackgroundColor: kRoseLight, selectedForegroundColor: kRose, backgroundColor: Colors.white, side: const BorderSide(color: kPinkBorder))),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: kRoseLight,
          checkmarkColor: kRose,
          side: const BorderSide(color: Color(0xFFF3D3DC)),
          labelStyle: const TextStyle(color: kInk),
          secondaryLabelStyle: const TextStyle(color: kRose),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0xFFF2B8C6)),
          trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kRose : const Color(0xFFFFF1F4)),
          trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kRose : const Color(0xFFF2B8C6)),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kRose : Colors.transparent),
          side: const BorderSide(color: kRoseSoft, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kRose : kRoseSoft)),
        sliderTheme: const SliderThemeData(activeTrackColor: kRose, inactiveTrackColor: kRoseLight, thumbColor: kRose, overlayColor: Color(0x22EC4A6E), valueIndicatorColor: kRose),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: kRose, linearTrackColor: kRoseLight, circularTrackColor: Colors.transparent, refreshBackgroundColor: Colors.white),
        tabBarTheme: const TabBarThemeData(
          labelColor: kRose,
          unselectedLabelColor: Color(0xFF6E6468),
          indicatorColor: kRose,
          dividerColor: kPinkLine,
          labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kRose, width: 1.6)),
          hintStyle: const TextStyle(color: Color(0xFFB9AEB2)),
        ),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: kRose, selectionColor: Color(0x55F7A9BC), selectionHandleColor: kRose),
        snackBarTheme: const SnackBarThemeData(backgroundColor: Color(0xFF3A2A31), behavior: SnackBarBehavior.floating),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: kSheetBg,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: kRoseLight,
          headerForegroundColor: kRoseDark,
          todayForegroundColor: const WidgetStatePropertyAll(kRose),
          todayBorder: const BorderSide(color: kRose),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
      ),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  static final ValueNotifier<int> tab = ValueNotifier(0);
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  @override
  void initState() {
    super.initState();
    Shell.tab.addListener(_on);
  }

  void _on() => setState(() {});

  @override
  void dispose() {
    Shell.tab.removeListener(_on);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idx = Shell.tab.value;
    return Scaffold(
      body: IndexedStack(index: idx, children: const [HomePage(), WardrobePage(), OutfitsPage(), CalendarPage(), MinePage()]),
      extendBody: false,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xF7FFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Color(0x14E8456B), blurRadius: 16, offset: Offset(0, -2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
        backgroundColor: Colors.transparent,
        selectedIndex: idx,
        onDestinationSelected: (i) => Shell.tab.value = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom), label: '单品'),
          NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: '搭配'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '日历'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
      ),
    );
  }
}

/// 页面切换：沿用平台默认动画，但每个页面都铺上淡粉渐变底（Scaffold 为透明）
class PinkPageTransitions extends PageTransitionsBuilder {
  const PinkPageTransitions();
  static const _inner = ZoomPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      _inner.buildTransitions<T>(route, context, animation, secondaryAnimation, PinkBackground(child: child));
}
