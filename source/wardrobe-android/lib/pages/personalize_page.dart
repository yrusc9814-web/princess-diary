import 'package:flutter/material.dart';

import '../data/db.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import 'filter_settings_page.dart';

class PersonalizePage extends StatefulWidget {
  const PersonalizePage({super.key});
  @override
  State<PersonalizePage> createState() => _PersonalizePageState();
}

class _PersonalizePageState extends State<PersonalizePage> {
  @override
  Widget build(BuildContext context) {
    final cats = Settings.disabledCats, slots = Settings.disabledSlots;
    Widget sw(String t, String? sub, bool v, ValueChanged<bool> on) => SwitchListTile(
          title: Text(t),
          subtitle: sub == null ? null : Text(sub, style: const TextStyle(fontSize: 12, color: kGrayText)),
          value: v,
          onChanged: (x) {
            setState(() => on(x));
            bump();
          },
        );
    return Scaffold(
      appBar: appBar('个性化'),
      body: ListView(children: [
        FormGroup([
          sw('列表显示衣物名称', null, Settings.showClothesName, (v) => Settings.showClothesName = v),
          sw('列表显示穿搭名称', null, Settings.showOutfitName, (v) => Settings.showOutfitName = v),
          sw('自动识别衣物信息', '添加单品时用本地模型预填品类、颜色、材质等', Settings.autoRecognize, (v) => Settings.autoRecognize = v),
          sw('自动识别到新分类时提醒添加', null, Settings.remindNewCategory, (v) => Settings.remindNewCategory = v),
          sw('批量添加页自动去背景', null, Settings.batchAutoCutout, (v) => Settings.batchAutoCutout = v),
        ]),
        FormGroup([
          ListTile(
            title: const Text('自动搭配过滤设置'),
            subtitle: Text(cats.isEmpty && slots.isEmpty ? '未设置' : '已禁用 ${cats.length} 个品类、${slots.length} 个搭配位',
                style: const TextStyle(fontSize: 12, color: kGrayText)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(context, const FilterSettingsPage()).then((_) => setState(() {})),
          ),
        ]),
      ]),
    );
  }
}
