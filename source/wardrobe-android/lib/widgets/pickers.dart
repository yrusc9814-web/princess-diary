import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/taxonomy.dart';
import 'common.dart';

/// 选择结果包装：返回 null = 取消；Picked(null) = 清空
class Picked<T> {
  final T? value;
  const Picked(this.value);
}

Widget _dialogActions(BuildContext c, {VoidCallback? onOk, String ok = '确定', bool showOk = true}) => Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        if (showOk) TextButton(onPressed: onOk, child: Text(ok)),
      ],
    );

// ================================================================= 衣物品类（两列滚轮）
Future<Picked<List<String>>?> pickSysCategory(BuildContext context, String? c1, String? c2) {
  final l1s = sysCategories.keys.toList();
  var i1 = c1 == null ? 0 : l1s.indexOf(c1).clamp(0, l1s.length - 1);
  List<String> l2Of(int i) => ['不设置', ...sysCategories[l1s[i]]!];
  var i2 = c2 == null ? 0 : l2Of(i1).indexOf(c2).clamp(0, 99);
  final c2Ctl = FixedExtentScrollController(initialItem: i2);
  return showDialog<Picked<List<String>>>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final l2 = l2Of(i1);
      Widget wheel(List<String> items, int sel, FixedExtentScrollController? ctl, ValueChanged<int> on, IconData icon) => SizedBox(
            height: 220,
            child: CupertinoPicker(
              scrollController: ctl ?? FixedExtentScrollController(initialItem: sel),
              itemExtent: 40,
              selectionOverlay: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: const Color(0x33F7A9BC), borderRadius: BorderRadius.circular(12)),
              ),
              onSelectedItemChanged: on,
              children: [
                for (final t in items)
                  Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 15, color: kGrayText),
                      const SizedBox(width: 4),
                      Flexible(child: Text(t, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))),
                    ]),
                  ),
              ],
            ),
          );
      final selText = i2 == 0 ? l1s[i1] : '${l1s[i1]} > ${l2[i2.clamp(0, l2.length - 1)]}';
      return AlertDialog(
        title: Row(children: [
          const Text('衣物品类'),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(c, const Picked<List<String>>(null)), child: const Text('清空')),
        ]),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Row(children: [
              Expanded(child: Center(child: Text('一级衣物品类', style: TextStyle(fontSize: 12, color: kGrayText)))),
              Expanded(child: Center(child: Text('二级衣物品类', style: TextStyle(fontSize: 12, color: kGrayText)))),
            ]),
            Row(children: [
              Expanded(
                  child: wheel(l1s, i1, null, (v) {
                set(() {
                  i1 = v;
                  i2 = 0;
                });
                c2Ctl.jumpToItem(0);
              }, Icons.folder_outlined)),
              Expanded(child: wheel(l2, i2, c2Ctl, (v) => set(() => i2 = v), Icons.subdirectory_arrow_right)),
            ]),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              width: double.infinity,
              decoration: BoxDecoration(color: kRoseBg, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 16, color: kRose),
                const SizedBox(width: 6),
                Expanded(child: Text('已选择：$selText', style: const TextStyle(color: kRose, fontSize: 13))),
              ]),
            ),
          ]),
        ),
        actions: [
          _dialogActions(c, onOk: () {
            final v2 = i2 == 0 ? null : l2[i2.clamp(0, l2.length - 1)];
            Navigator.pop(c, Picked<List<String>>([l1s[i1], if (v2 != null) v2]));
          }),
        ],
      );
    }),
  );
}

// ================================================================= 自定义分类
Future<CustomCat?> addCustomCatDialog(BuildContext context, {CustomCat? edit, int? parentId}) async {
  final cats = (await AppDb.I.customCats()).where((e) => e.parentId == null && e.id != edit?.id).toList();
  final name = TextEditingController(text: edit?.name ?? '');
  final desc = TextEditingController(text: edit?.description ?? '');
  int? parent = edit?.parentId ?? parentId;
  if (!context.mounted) return null;
  return showDialog<CustomCat>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(edit == null ? '添加自定义分类' : '编辑自定义分类'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: '自定义分类名称')),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: parent,
            decoration: const InputDecoration(labelText: '所属一级自定义分类（可选）'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('无 (一级自定义分类)')),
              for (final p in cats) DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => set(() => parent = v),
          ),
          const SizedBox(height: 8),
          TextField(controller: desc, decoration: const InputDecoration(labelText: '描述')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                toast(c, '请输入自定义分类名称');
                return;
              }
              final cat = edit ?? CustomCat(name: '');
              cat
                ..name = name.text.trim()
                ..parentId = parent
                ..description = desc.text.trim();
              await AppDb.I.saveCustomCat(cat);
              if (c.mounted) Navigator.pop(c, cat);
            },
            child: Text(edit == null ? '创建' : '保存'),
          ),
        ],
      ),
    ),
  );
}

Future<Picked<int>?> pickCustomCat(BuildContext context, int? current) async {
  return showDialog<Picked<int>>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      return FutureBuilder<List<CustomCat>>(
        future: AppDb.I.customCats(),
        builder: (c, snap) {
          final cats = snap.data ?? [];
          final tops = cats.where((e) => e.parentId == null).toList();
          return AlertDialog(
            title: Row(children: [
              const Text('自定义分类'),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final n = await addCustomCatDialog(c);
                  if (n != null) set(() {});
                },
                child: const Text('+添加自定义分类', style: TextStyle(fontSize: 13)),
              ),
            ]),
            contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            content: SizedBox(
              width: 320,
              child: cats.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.category_outlined, size: 48, color: kRoseSoft),
                        SizedBox(height: 10),
                        Text('暂无自定义分类', style: TextStyle(fontSize: 15)),
                        SizedBox(height: 4),
                        Text('点击右上角“添加自定义分类”创建新分类', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kGrayText)),
                      ]),
                    )
                  : ListView(shrinkWrap: true, children: [
                      ListTile(
                        title: const Text('不设置'),
                        trailing: current == null ? const Icon(Icons.check, color: kRose) : null,
                        onTap: () => Navigator.pop(c, const Picked<int>(null)),
                      ),
                      for (final t in tops) ...[
                        ListTile(
                          leading: const Icon(Icons.folder_outlined, size: 20),
                          title: Text(t.name),
                          trailing: current == t.id ? const Icon(Icons.check, color: kRose) : null,
                          onTap: () => Navigator.pop(c, Picked<int>(t.id)),
                        ),
                        for (final s in cats.where((e) => e.parentId == t.id))
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 40, right: 16),
                            leading: const Icon(Icons.subdirectory_arrow_right, size: 18),
                            title: Text(s.name),
                            trailing: current == s.id ? const Icon(Icons.check, color: kRose) : null,
                            onTap: () => Navigator.pop(c, Picked<int>(s.id)),
                          ),
                      ],
                    ]),
            ),
            actions: [_dialogActions(c, showOk: false)],
          );
        },
      );
    }),
  );
}

// ================================================================= 状态
Future<String?> pickStatus(BuildContext context, String current) => showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('选择状态'),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in statusOptions)
            RadioListTile<String>(
              value: s,
              // ignore: deprecated_member_use
              groupValue: current,
              // ignore: deprecated_member_use
              onChanged: (v) => Navigator.pop(c, v),
              title: Text(s),
              subtitle: s == '丢弃' ? const Text('默认隐藏，需筛选“丢弃”可见', style: TextStyle(fontSize: 12)) : null,
            ),
        ]),
        actions: [_dialogActions(c, showOk: false)],
      ),
    );

// ================================================================= 季节
Future<List<String>?> pickSeasons(BuildContext context, List<String> current) {
  final sel = [...current];
  return showDialog<List<String>>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('选择季节'),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in seasonOptions)
            CheckboxListTile(
              value: sel.contains(s),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(s),
              onChanged: (v) => set(() => v! ? sel.add(s) : sel.remove(s)),
            ),
        ]),
        actions: [
          _dialogActions(c, onOk: () => Navigator.pop(c, seasonOptions.where(sel.contains).toList())),
        ],
      ),
    ),
  );
}

// ================================================================= 收纳位置
Future<DictItem?> addStorageDialog(BuildContext context, {DictItem? edit}) {
  final name = TextEditingController(text: edit?.name ?? '');
  final desc = TextEditingController(text: edit?.description ?? '');
  return showDialog<DictItem>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(edit == null ? '添加收纳位置' : '编辑收纳位置'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: '位置名称')),
        const SizedBox(height: 8),
        TextField(controller: desc, decoration: const InputDecoration(labelText: '描述（可选）')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        TextButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) {
              toast(c, '请输入位置名称');
              return;
            }
            DictItem d;
            if (edit == null) {
              final id = await AppDb.I.addDict('storage', name.text.trim(), description: desc.text.trim());
              d = DictItem(id: id, type: 'storage', name: name.text.trim(), description: desc.text.trim());
              toast(c, '收纳位置创建成功');
            } else {
              d = edit
                ..name = name.text.trim()
                ..description = desc.text.trim();
              await AppDb.I.updateDict(d);
            }
            if (c.mounted) Navigator.pop(c, d);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

Future<Picked<int>?> pickStorage(BuildContext context, int? current) => showDialog<Picked<int>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => FutureBuilder<List<DictItem>>(
          future: AppDb.I.dicts('storage'),
          builder: (c, snap) => AlertDialog(
            title: Row(children: [
              const Text('选择收纳位置'),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final d = await addStorageDialog(c);
                  if (d != null) set(() {});
                },
                child: const Text('添加收纳位置', style: TextStyle(fontSize: 13)),
              ),
            ]),
            contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            content: SizedBox(
              width: 320,
              child: ListView(shrinkWrap: true, children: [
                ListTile(
                  title: const Text('不设置'),
                  trailing: current == null ? const Icon(Icons.check, color: kRose) : null,
                  onTap: () => Navigator.pop(c, const Picked<int>(null)),
                ),
                for (final d in snap.data ?? <DictItem>[])
                  ListTile(
                    title: Text(d.name),
                    subtitle: d.description.isEmpty ? null : Text(d.description),
                    trailing: current == d.id ? const Icon(Icons.check, color: kRose) : null,
                    onTap: () => Navigator.pop(c, Picked<int>(d.id)),
                  ),
              ]),
            ),
            actions: [_dialogActions(c, showOk: false)],
          ),
        ),
      ),
    );

// ================================================================= 品牌
Future<Picked<String>?> pickBrand(BuildContext context, String? current) async {
  final custom = (await AppDb.I.dicts('brand')).map((e) => e.name).toList();
  final all = {...builtinBrands, ...custom}.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  var q = '';
  if (!context.mounted) return null;
  return showDialog<Picked<String>>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final list = q.isEmpty ? all : all.where((b) => b.toLowerCase().contains(q.toLowerCase())).toList();
      final exact = all.any((b) => b.toLowerCase() == q.toLowerCase());
      return AlertDialog(
        title: Row(children: [
          const Text('选择品牌'),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(c, const Picked<String>(null)), child: const Text('清空')),
        ]),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        content: SizedBox(
          width: 320,
          height: 420,
          child: Column(children: [
            TextField(
              decoration: InputDecoration(
                hintText: '搜索品牌...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: kCellBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onChanged: (v) => set(() => q = v.trim()),
            ),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerLeft, child: Text('全部品牌', style: TextStyle(color: kRose, fontSize: 12))),
            Expanded(
              child: ListView(children: [
                if (q.isNotEmpty && !exact)
                  ListTile(
                    leading: const IconTile(Icons.add, size: 38, iconSize: 20),
                    title: Text('添加自定义品牌「$q」', style: const TextStyle(color: kRose)),
                    onTap: () async {
                      await AppDb.I.addDict('brand', q);
                      if (c.mounted) Navigator.pop(c, Picked<String>(q));
                    },
                  ),
                for (final b in list)
                  ListTile(
                    dense: true,
                    title: Text(b, style: const TextStyle(fontSize: 15)),
                    trailing: current == b ? const Icon(Icons.check, color: kRose) : null,
                    onTap: () => Navigator.pop(c, Picked<String>(b)),
                  ),
              ]),
            ),
          ]),
        ),
        actions: [_dialogActions(c, showOk: false)],
      );
    }),
  );
}

// ================================================================= 日期（年/月/日 三列滚轮）
Future<DateTime?> pickDate(BuildContext context, DateTime? initial, {String title = '选择日期', int fromYear = 2000, int toYear = 2035}) {
  var d = initial ?? DateTime.now();
  var y = d.year.clamp(fromYear, toYear), m = d.month, day = d.day;
  final dayCtl = FixedExtentScrollController(initialItem: day - 1);
  int daysIn(int y, int m) => DateTime(y, m + 1, 0).day;
  return showDialog<DateTime>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final nd = daysIn(y, m);
      if (day > nd) day = nd;
      Widget wheel(int count, int sel, String Function(int) label, ValueChanged<int> on, {FixedExtentScrollController? ctl}) => Expanded(
            child: SizedBox(
              height: 200,
              child: CupertinoPicker(
                scrollController: ctl ?? FixedExtentScrollController(initialItem: sel),
                itemExtent: 40,
                onSelectedItemChanged: on,
                children: [for (var i = 0; i < count; i++) Center(child: Text(label(i), style: const TextStyle(fontSize: 16)))],
              ),
            ),
          );
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 300,
          child: Row(children: [
            wheel(toYear - fromYear + 1, y - fromYear, (i) => '${fromYear + i}年', (i) => set(() => y = fromYear + i)),
            wheel(12, m - 1, (i) => '${i + 1}月', (i) => set(() => m = i + 1)),
            wheel(nd, day - 1, (i) => '${i + 1}日', (i) => set(() => day = i + 1), ctl: dayCtl),
          ]),
        ),
        actions: [_dialogActions(c, onOk: () => Navigator.pop(c, DateTime(y, m, day.clamp(1, daysIn(y, m)))))],
      );
    }),
  );
}

// ================================================================= 单选列表（风格/材质/保暖度/轮廓/长度）
Future<Picked<String>?> pickOption(BuildContext context, String title, List<String> options, String? current) =>
    showDialog<Picked<String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        content: SizedBox(
          width: 300,
          child: ListView(shrinkWrap: true, children: [
            ListTile(
              title: const Text('不设置'),
              trailing: (current == null || current.isEmpty) ? const Icon(Icons.check, color: kRose) : null,
              onTap: () => Navigator.pop(c, const Picked<String>(null)),
            ),
            for (final o in options)
              ListTile(
                title: Text(o),
                trailing: current == o ? const Icon(Icons.check, color: kRose) : null,
                onTap: () => Navigator.pop(c, Picked<String>(o)),
              ),
          ]),
        ),
        actions: [_dialogActions(c, showOk: false)],
      ),
    );

// ================================================================= 标签 / 场合（多选，自行设计）
Future<List<int>?> pickDictMulti(BuildContext context, String type, List<int> current, {String? title}) {
  final sel = [...current];
  final t = title ?? (type == 'occasion' ? '选择场合' : '选择标签');
  final addLabel = type == 'occasion' ? '添加场合' : '添加标签';
  return showSheet<List<int>>(
    context,
    (c) => StatefulBuilder(
      builder: (c, set) => FutureBuilder<List<DictItem>>(
        future: AppDb.I.dicts(type),
        builder: (c, snap) {
          final items = snap.data ?? [];
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
                child: Row(children: [
                  Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final n = await inputDialog(c, addLabel, hint: type == 'occasion' ? '场合名称' : '标签名称');
                      if (n != null && n.isNotEmpty) {
                        final id = await AppDb.I.addDict(type, n);
                        set(() => sel.add(id));
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(addLabel),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: items.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(border: Border.all(color: kPinkBorder), borderRadius: BorderRadius.circular(12)),
                        child: Text(type == 'occasion' ? '暂无场合，点击右上角添加' : '暂无可用标签，点击右上角添加',
                            textAlign: TextAlign.center, style: const TextStyle(color: kGrayText)),
                      )
                    : Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final d in items)
                          Pill(d.name, selected: sel.contains(d.id), onTap: () => set(() => sel.contains(d.id) ? sel.remove(d.id) : sel.add(d.id!))),
                      ]),
              ),
              const SizedBox(height: 12),
              BottomButtons(onCancel: () => Navigator.pop(c), onOk: () => Navigator.pop(c, sel)),
            ]),
          );
        },
      ),
    ),
  );
}

// ================================================================= 颜色
Future<List<String>?> pickColors(BuildContext context, List<String> current, {Future<List<String>> Function()? recognize}) {
  final sel = <String?>[...current.take(3)];
  while (sel.length < 3) {
    sel.add(null);
  }
  var slot = 0;
  var busy = false;
  return showSheet<List<String>>(
    context,
    (c) => StatefulBuilder(builder: (c, set) {
      Widget slotW(int i, String label) => GestureDetector(
            onTap: () => set(() => slot = i),
            child: Column(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel[i] == null ? kCellBg : colorOf(sel[i]!),
                  border: Border.all(color: slot == i ? kRose : const Color(0xFFF5D5DE), width: slot == i ? 2.5 : 1),
                ),
                child: sel[i] == null
                    ? const Icon(Icons.add, color: kGrayText)
                    : GestureDetector(
                        onTap: () => set(() => sel[i] = null),
                        child: const Align(alignment: Alignment.topRight, child: Icon(Icons.cancel, size: 14, color: kRoseSoft))),
              ),
              const SizedBox(height: 4),
              Text(sel[i] ?? label, style: TextStyle(fontSize: 12, color: slot == i ? kRose : kGrayText)),
            ]),
          );
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(children: [
            const Text('选择颜色', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (recognize != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, shape: const StadiumBorder()),
                onPressed: busy
                    ? null
                    : () async {
                        set(() => busy = true);
                        final r = await recognize();
                        set(() {
                          busy = false;
                          for (var i = 0; i < 3; i++) {
                            sel[i] = i < r.length ? r[i] : null;
                          }
                        });
                      },
                icon: busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 16),
                label: const Text('识别'),
              ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(c, sel.whereType<String>().toList()), child: const Text('保存')),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Align(alignment: Alignment.centerLeft, child: Text('已选颜色', style: TextStyle(fontWeight: FontWeight.w600))),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [slotW(0, '主色'), slotW(1, '配色1'), slotW(2, '配色2')]),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Align(alignment: Alignment.centerLeft, child: Text('颜色选项', style: TextStyle(fontWeight: FontWeight.w600))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            childAspectRatio: 0.8,
            children: [
              for (final o in colorOptions)
                GestureDetector(
                  onTap: () => set(() {
                    final ex = sel.indexOf(o.name);
                    if (ex >= 0) sel[ex] = null;
                    sel[slot] = o.name;
                    final next = sel.indexOf(null);
                    if (next >= 0) slot = next;
                  }),
                  child: Column(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: o.name == '多色'
                            ? const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red])
                            : null,
                        color: o.name == '多色' ? null : o.color,
                        border: Border.all(color: sel.contains(o.name) ? kRose : Colors.black12, width: sel.contains(o.name) ? 2.5 : 1),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(o.name, style: const TextStyle(fontSize: 11)),
                  ]),
                ),
            ],
          ),
        ),
        SizedBox(height: 16 + MediaQuery.of(c).padding.bottom),
      ]);
    }),
  );
}
