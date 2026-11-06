import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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
              color: const Color(0xFFFFF6EA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF6C58E)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFE8711C)),
                SizedBox(width: 8),
                Text('数据仅保存在本机', style: TextStyle(color: Color(0xFFE8711C), fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              const Text.rich(
                TextSpan(style: TextStyle(color: Color(0xFFE8711C), height: 1.6, fontSize: 14), children: [
                  TextSpan(text: '当前图片数据仅保存在本机。'),
                  TextSpan(text: '卸载应用、清空应用数据或丢失手机将导致图片永久丢失！', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '建议定期手动导出备份。'),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFFE7CC), borderRadius: BorderRadius.circular(16)),
                child: Text(last == 0 ? '上次导出：从未导出' : '上次导出：${_fmt(last)}', style: const TextStyle(color: Color(0xFFB85A12), fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('手动备份与迁移', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('将数据打包导出，用于在其他设备恢复。', style: TextStyle(color: kGrayText)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kPurpleBg,
                  foregroundColor: kPurple,
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder(),
                  elevation: 1,
                ),
                onPressed: busy ? null : _export,
                icon: const Icon(Icons.upload_file),
                label: const Text('导出备份包'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder(), foregroundColor: kPurple),
                onPressed: busy ? null : _import,
                icon: const Icon(Icons.download_for_offline),
                label: const Text('导入备份包'),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          const Text('备份包为 .wrdx 文件（数据 + 全部图片），可通过微信、网盘、电脑等保存。也支持导入 1.0 版导出的 .zip 备份。',
              style: TextStyle(fontSize: 12, color: kGrayText, height: 1.6)),
        ]),
        if (busy)
          Container(
            color: Colors.black26,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(busyText)]),
              ),
            ),
          ),
      ]),
    );
  }
}
