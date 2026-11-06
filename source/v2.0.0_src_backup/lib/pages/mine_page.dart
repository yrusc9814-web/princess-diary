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
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE6F0FF), Color(0xFFF1E9FB)]),
          ),
          child: Column(children: [
            Row(children: [
              const CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Icon(Icons.person, size: 34, color: kPurple)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('衣橱搭子', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$clothes 件衣物 · $outfits 套搭配', style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 14),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => push(context, const BackupPage()).then((_) => setState(() {})),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const CircleAvatar(radius: 20, backgroundColor: Color(0xFFF2F2F5), child: Icon(Icons.phonelink_lock_outlined, color: Colors.black54, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('图片仅保存在本地', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(last == 0 ? '卸载/换机记得导出备份' : '上次导出：${_fmt(last)}', style: const TextStyle(color: kGrayText, fontSize: 12)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: kGrayText),
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
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: const Color(0xFFF4F4F6), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 21, color: Colors.black87),
        ),
        title: Text(t, style: const TextStyle(fontSize: 16)),
        subtitle: sub == null ? null : Text(sub, style: const TextStyle(color: kGrayText, fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right, color: kGrayText),
        onTap: onTap,
      );
}
