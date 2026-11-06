import 'package:flutter/material.dart';

import '../data/taxonomy.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

/// 自动搭配过滤设置
class FilterSettingsPage extends StatefulWidget {
  const FilterSettingsPage({super.key});
  @override
  State<FilterSettingsPage> createState() => _FilterSettingsPageState();
}

class _FilterSettingsPageState extends State<FilterSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final cats = Settings.disabledCats;
    final slots = Settings.disabledSlots;
    return Scaffold(
      appBar: appBar('自动搭配过滤设置'),
      body: ListView(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFEFEFF2), borderRadius: BorderRadius.circular(14)),
          child: const Text('该配置会影响独立自动搭配和详情页自动搭配；详情页会临时放开当前主单品。', style: TextStyle(color: kGrayText, fontSize: 13, height: 1.5)),
        ),
        FormGroup([
          _row('禁用系统分类', cats.isEmpty ? '未设置' : cats.join('、'), () async {
            final r = await _pickCats(context, cats);
            if (r != null) {
              Settings.disabledCats = r;
              setState(() {});
              toast(null, '保存成功');
            }
          }),
          _row('禁用搭配位', slots.isEmpty ? '未设置' : slots.join('、'), () async {
            final r = await _pickSlots(context, slots);
            if (r != null) {
              Settings.disabledSlots = r;
              setState(() {});
              toast(null, '保存成功');
            }
          }),
        ]),
      ]),
    );
  }

  Widget _row(String t, String sub, VoidCallback onTap) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kGrayText)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

Future<List<String>?> _pickCats(BuildContext context, List<String> current) {
  final sel = {...current};
  final open = <String>{};
  const l1s = ['上装', '下装', '连衣裙', '连体装', '外套', '鞋履', '包袋', '配饰'];
  return showDialog<List<String>>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      bool? state(String l1) {
        if (sel.contains(l1)) return true;
        final kids = sysCategories[l1]!;
        final n = kids.where((k) => sel.contains('$l1/$k')).length;
        return n == 0 ? false : (n == kids.length ? true : null);
      }

      return AlertDialog(
        title: const Text('选择衣物品类', style: TextStyle(fontWeight: FontWeight.w700)),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        content: SizedBox(
          width: 320,
          child: ListView(shrinkWrap: true, children: [
            for (final l1 in l1s) ...[
              ListTile(
                title: Text(l1),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(
                    tristate: true,
                    value: state(l1),
                    onChanged: (_) => set(() {
                      final on = state(l1) != true;
                      sel.removeWhere((e) => e == l1 || e.startsWith('$l1/'));
                      if (on) sel.add(l1);
                    }),
                  ),
                  IconButton(
                    icon: Icon(open.contains(l1) ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => set(() => open.contains(l1) ? open.remove(l1) : open.add(l1)),
                  ),
                ]),
              ),
              if (open.contains(l1))
                for (final k in sysCategories[l1]!)
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.only(left: 36, right: 56),
                    dense: true,
                    title: Text(k),
                    value: sel.contains(l1) || sel.contains('$l1/$k'),
                    onChanged: (v) => set(() {
                      if (sel.contains(l1)) {
                        sel.remove(l1);
                        sel.addAll(sysCategories[l1]!.map((e) => '$l1/$e'));
                      }
                      v! ? sel.add('$l1/$k') : sel.remove('$l1/$k');
                      if (sysCategories[l1]!.every((e) => sel.contains('$l1/$e'))) {
                        sel.removeWhere((e) => e.startsWith('$l1/'));
                        sel.add(l1);
                      }
                    }),
                  ),
            ],
          ]),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size.fromHeight(44)),
                onPressed: () => Navigator.pop(c),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kPurple, shape: const StadiumBorder(), minimumSize: const Size.fromHeight(44)),
                onPressed: () => Navigator.pop(c, sel.toList()),
                child: const Text('确定'),
              ),
            ),
          ]),
        ],
      );
    }),
  );
}

Future<List<String>?> _pickSlots(BuildContext context, List<String> current) {
  final sel = {...current};
  return showDialog<List<String>>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('禁用搭配位'),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in disableSlotOptions)
            CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(s),
              value: sel.contains(s),
              onChanged: (v) => set(() => v! ? sel.add(s) : sel.remove(s)),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          TextButton(onPressed: () => set(sel.clear), child: const Text('清空')),
          FilledButton.tonal(onPressed: () => Navigator.pop(c, sel.toList()), child: const Text('确定')),
        ],
      ),
    ),
  );
}
