import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/auto_backup.dart';
import '../services/backup.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

/// 数据迁移与备份
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool busy = false;
  String busyText = '';

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _export() async {
    setState(() {
      busy = true;
      busyText = '正在打包…';
    });
    try {
      final f = await Backup.export();
      final mb = (await f.length()) / 1024 / 1024;
      if (!mounted) return;
      setState(() => busy = false);
      toast(null, '分享面板已唤起（${mb.toStringAsFixed(2)}MB）', style: 'dark');
      await Share.shareXFiles([XFile(f.path, mimeType: 'application/octet-stream')], subject: f.uri.pathSegments.last);
    } catch (e) {
      if (mounted) setState(() => busy = false);
      toast(null, '导出失败：$e', style: 'dark');
    }
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path == null || !mounted) return;
    final lower = path.toLowerCase();
    if (!lower.endsWith('.wrdx') && !lower.endsWith('.zip')) {
      toast(null, '请选择 .wrdx 备份包');
      return;
    }
    if (!await confirm(context, '导入备份包', '导入会用备份包覆盖当前所有数据，确定继续？', ok: '导入')) return;
    setState(() {
      busy = true;
      busyText = '正在导入…';
    });
    try {
      final n = await Backup.import(path);
      toast(null, '导入完成，共 $n 件衣物');
    } catch (e) {
      toast(null, e is FormatException ? e.message : '导入失败：$e', style: 'dark');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _toggleAuto(bool on) async {
    Settings.autoBackupEnabled = on;
    setState(() {});
    try {
      if (on) {
        await AutoBackupService.schedule();
        toast(null, '已开启，每天凌晨 3 点自动备份');
      } else {
        await AutoBackupService.cancel();
        toast(null, '已关闭自动备份');
      }
    } catch (e) {
      toast(null, '设置失败：$e', style: 'dark');
    }
  }

  /// 手动触发一次（验证用）：立刻按自动备份的完整流程跑一遍。
  Future<void> _runAutoNow() async {
    setState(() {
      busy = true;
      busyText = '正在检查并备份…';
    });
    try {
      final r = await AutoBackup().run();
      if (!mounted) return;
      toast(null, r.skipped ? '数据无变化，已跳过' : (r.ok ? '已备份：${r.fileName}' : '备份失败：${r.error}'), style: r.ok ? 'success' : 'dark');
    } catch (e) {
      toast(null, '备份失败：$e', style: 'dark');
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _autoCard() {
    final on = Settings.autoBackupEnabled;
    final at = Settings.autoBackupAt;
    final file = Settings.autoBackupFile;
    final check = Settings.autoBackupLastCheck;
    final err = Settings.autoBackupError;
    final skipped = check > 0 && check > at;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xEEFFFFFF),
        boxShadow: kCardShadow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kPinkBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.schedule, color: kRose),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('自动备份', style: TextStyle(color: kInk, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Switch(value: on, onChanged: busy ? null : _toggleAuto),
        ]),
        Text(
          on ? '每天凌晨 3 点左右自动备份一次' : '已关闭，不会自动备份',
          style: const TextStyle(color: kGrayText, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _kv('上次自动备份', at == 0 ? '暂无' : _fmt(at)),
        _kv('备份文件', file.isEmpty ? '暂无' : file),
        _kv('上次检查', check == 0 ? '暂无' : _fmt(check)),
        if (skipped) const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text('数据无变化，已跳过', style: TextStyle(color: kRose, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        if (err.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('上次失败：$err', style: const TextStyle(color: kRoseDark, fontSize: 12)),
        ),
        const SizedBox(height: 10),
        const Text('每天凌晨 3 点自动备份到 文档/公主日记备份，只保留最新一份；手机省电可能让时间稍晚。',
            style: TextStyle(fontSize: 12, color: kGrayText, height: 1.6)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: busy ? null : _runAutoNow,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('立即检查并备份'),
          ),
        ),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(k, style: const TextStyle(fontSize: 13, color: kGrayText))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, color: kInk))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final last = Settings.lastExport;
    return Scaffold(
      appBar: appBar('数据迁移与备份'),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xEEFFFFFF),
              boxShadow: kCardShadow,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kPinkBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.warning_amber_rounded, color: kRoseDark),
                SizedBox(width: 8),
                Text('数据仅保存在本机', style: TextStyle(color: kRoseDark, fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              const Text.rich(
                TextSpan(style: TextStyle(color: kRoseDark, height: 1.6, fontSize: 14), children: [
                  TextSpan(text: '当前图片数据仅保存在本机。'),
                  TextSpan(text: '卸载应用、清空应用数据或丢失手机将导致图片永久丢失！', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '建议定期手动导出备份。'),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: kRoseLight, borderRadius: BorderRadius.circular(16)),
                child: Text(last == 0 ? '上次导出：从未导出' : '上次导出：${_fmt(last)}', style: const TextStyle(color: kRoseDark, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _autoCard(),
          const SizedBox(height: 24),
          const Text('手动备份与迁移', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kInk)),
          const SizedBox(height: 8),
          const Text('将数据打包导出，用于在其他设备恢复。', style: TextStyle(color: kGrayText)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kRose,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                onPressed: busy ? null : _export,
                icon: const Icon(Icons.upload_file),
                label: const Text('导出备份包'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder(), foregroundColor: kRose, backgroundColor: Colors.white, side: const BorderSide(color: kPinkBorder)),
                onPressed: busy ? null : _import,
                icon: const Icon(Icons.download_for_offline),
                label: const Text('导入备份包'),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          const Text('备份包为 .wrdx 文件（数据 + 全部图片），文件名为 gongzhuriji_年-月-日_时分.wrdx，可通过微信、网盘、电脑等保存。'
              '也支持导入 1.0 版导出的 .zip 备份。',
              style: TextStyle(fontSize: 12, color: kGrayText, height: 1.6)),
        ]),
        if (busy)
          Container(
            color: const Color(0x33E8456B),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: kSheetBg, borderRadius: BorderRadius.circular(22), boxShadow: kSoftShadow),
                child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(busyText)]),
              ),
            ),
          ),
      ]),
    );
  }
}
