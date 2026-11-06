import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/settings.dart';
import '../widgets/common.dart';
import 'backup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final key = Settings.dashscopeKey;
    return Scaffold(
      appBar: appBar('设置'),
      body: ListView(children: [
        FormGroup([
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('数据备份与迁移'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(context, const BackupPage()),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('AI 试衣（阿里云百炼）'),
            subtitle: Text(key.isEmpty ? '未填写 API Key' : '已填写 API Key（${key.length > 8 ? '${key.substring(0, 5)}…${key.substring(key.length - 3)}' : '***'}）· ${Settings.tryOnModel}',
                style: const TextStyle(fontSize: 12, color: kGrayText)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _tryOnKey,
          ),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('当前版本'), trailing: Text('2.0.0', style: TextStyle(color: kGrayText))),
        ]),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Text('本应用为纯本地版本：无账号、无云端同步，所有数据和图片只保存在本机。卸载或换机前请在「数据备份与迁移」中导出备份包。',
              style: TextStyle(fontSize: 12, color: kGrayText, height: 1.6)),
        ),
      ]),
    );
  }

  Future<void> _tryOnKey() async {
    final ctl = TextEditingController(text: Settings.dashscopeKey);
    var model = Settings.tryOnModel;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('AI 试衣设置'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('使用阿里云百炼「AI 试衣」接口，按张计费（新用户有免费额度）。需华北2（北京）地域的 API Key。', style: TextStyle(fontSize: 13, color: kGrayText, height: 1.5)),
              const SizedBox(height: 10),
              TextField(controller: ctl, decoration: const InputDecoration(labelText: 'DashScope API Key', hintText: 'sk-...')),
              const SizedBox(height: 12),
              const Text('模型', style: TextStyle(fontWeight: FontWeight.w600)),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'aitryon',
                // ignore: deprecated_member_use
                groupValue: model,
                // ignore: deprecated_member_use
                onChanged: (v) => set(() => model = v!),
                title: const Text('aitryon（基础版，较快）'),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: 'aitryon-plus',
                // ignore: deprecated_member_use
                groupValue: model,
                // ignore: deprecated_member_use
                onChanged: (v) => set(() => model = v!),
                title: const Text('aitryon-plus（效果更好）'),
              ),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('https://bailian.console.aliyun.com/?apiKey=1'), mode: LaunchMode.externalApplication),
                child: const Text('去百炼控制台获取 API Key'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok == true) {
      Settings.dashscopeKey = ctl.text;
      Settings.tryOnModel = model;
      setState(() {});
      toast(null, '保存成功');
    }
  }
}
