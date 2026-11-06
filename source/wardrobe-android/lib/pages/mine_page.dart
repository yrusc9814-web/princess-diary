import 'package:flutter/material.dart';

import '../data/db.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import 'backup_page.dart';
import 'material_page.dart';
import 'personalize_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'tryon_page.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});
  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> with DataReload {
  int clothes = 0, outfits = 0;

  @override
  void initState() {
    super.initState();
    listenData(dataVersion);
    reload();
  }

  @override
  void dispose() {
    unlistenData(dataVersion);
    super.dispose();
  }

  @override
  Future<void> reload() async {
    final c = (await AppDb.I.allClothes()).where((e) => e.status != '丢弃').length;
    final o = (await AppDb.I.outfits()).length;
    if (mounted) {
      setState(() {
        clothes = c;
        outfits = o;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = Settings.lastExport;
    return Scaffold(
      appBar: appBar('我的'),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFCE1E8), Color(0xFFFBD3DE), Color(0xFFFDE6EC)]),
            boxShadow: kCardShadow,
          ),
          child: Column(children: [
            Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: kSoftShadow, border: Border.all(color: Colors.white, width: 2.5)),
                  child: ClipOval(child: Image.asset('assets/illustrations/avatar_princess.png', fit: BoxFit.cover)),
                ),
                const Positioned(right: -10, top: -2, child: Icon(Icons.auto_awesome, size: 16, color: kRoseSoft)),
              ]),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('公主日记', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
                const SizedBox(height: 4),
                Text('$clothes 件衣物 · $outfits 套搭配', style: const TextStyle(color: Color(0xFF7A6E73), fontSize: 13.5)),
              ]),
            ]),
            const SizedBox(height: 14),
            Material(
              color: const Color(0xF2FFFFFF),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => push(context, const BackupPage()).then((_) => setState(() {})),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const IconTile(Icons.phonelink_lock_outlined, size: 44, iconSize: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('图片仅保存在本地', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kInk)),
                        const SizedBox(height: 2),
                        Text(last == 0 ? '卸载/换机记得导出备份' : '上次导出：${_fmt(last)}', style: const TextStyle(color: kGrayText, fontSize: 12)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: kRose),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        FormGroup([
          _item(Icons.insights, '数据统计', '查看衣橱数据看板', () => push(context, const StatsPage())),
          _item(Icons.lightbulb_outline, '素材库', null, () => push(context, const MaterialLibraryPage())),
          _item(Icons.auto_awesome_outlined, 'AI 试衣', null, () => push(context, const TryOnPage())),
        ]),
        FormGroup([
          _item(Icons.tune, '个性化', null, () => push(context, const PersonalizePage())),
          _item(Icons.settings_outlined, '设置', null, () => push(context, const SettingsPage())),
        ]),
      ]),
    );
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _item(IconData icon, String t, String? sub, VoidCallback onTap) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: IconTile(icon, size: 44, iconSize: 23),
        title: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kInk)),
        subtitle: sub == null ? null : Text(sub, style: const TextStyle(color: kGrayText, fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right, color: kRose),
        onTap: onTap,
      );
}
