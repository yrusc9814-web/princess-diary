import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'clothes_detail_page.dart';

/// 素材库：你标为「素材」「种草」的单品
class MaterialLibraryPage extends StatefulWidget {
  const MaterialLibraryPage({super.key});
  @override
  State<MaterialLibraryPage> createState() => _MaterialLibraryPageState();
}

class _MaterialLibraryPageState extends State<MaterialLibraryPage> with DataReload {
  List<Clothes> all = [];
  List<CustomCat> cats = [];
  String q = '';
  int? catId;
  String status = ''; // '' / 素材 / 种草
  bool multi = false;
  final sel = <int>{};

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
    final a = (await AppDb.I.allClothes()).where((c) => c.status == '素材' || c.status == '种草').toList();
    final c = await AppDb.I.customCats();
    if (mounted) {
      setState(() {
        all = a;
        cats = c;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = catId == null ? null : {catId, ...cats.where((e) => e.parentId == catId).map((e) => e.id)};
    final list = all.where((c) {
      if (status.isNotEmpty && c.status != status) return false;
      if (ids != null && !ids.contains(c.customCatId)) return false;
      if (q.isNotEmpty) {
        final hay = '${c.name} ${c.brand ?? ''} ${c.cat1 ?? ''} ${c.cat2 ?? ''} ${c.note}';
        if (!hay.toLowerCase().contains(q.toLowerCase())) return false;
      }
      return true;
    }).toList();
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: appBar('素材库', actions: [
        IconButton(
          icon: Icon(multi ? Icons.close : Icons.checklist),
          tooltip: '多选',
          onPressed: () => setState(() {
            multi = !multi;
            sel.clear();
          }),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => q = v.trim()),
            decoration: InputDecoration(
              hintText: '搜索标题/店铺/品牌/类目',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            PopupMenuButton<int?>(
              onSelected: (v) => setState(() => catId = v == -1 ? null : v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: -1, child: Text('全部')),
                for (final c in cats.where((e) => e.parentId == null)) PopupMenuItem(value: c.id, child: Text(c.name)),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: catId == null ? Colors.white : kPurpleLight, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFDADADF))),
                child: Row(children: [
                  Text(catId == null ? '自定义分类' : cats.firstWhere((e) => e.id == catId).name, style: TextStyle(color: catId == null ? Colors.black87 : kPurple)),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Pill('素材', selected: status == '素材', icon: const SizedBox.shrink(), onTap: () => setState(() => status = status == '素材' ? '' : '素材')),
            const SizedBox(width: 8),
            Pill('种草', selected: status == '种草', icon: const SizedBox.shrink(), onTap: () => setState(() => status = status == '种草' ? '' : '种草')),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.lightbulb_outline,
                  title: '素材库还是空的',
                  sub: '编辑单品时把状态设为「素材」或「种草」，就会出现在这里，也可以用「淘宝导入」添加心仪商品',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.7),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final s = sel.contains(c.id);
                    return GestureDetector(
                      onTap: () {
                        if (multi) {
                          setState(() => s ? sel.remove(c.id) : sel.add(c.id!));
                        } else {
                          push(context, ClothesDetailPage(id: c.id!));
                        }
                      },
                      onLongPress: () => setState(() {
                        multi = true;
                        sel.add(c.id!);
                      }),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: s ? kPurple : Colors.transparent, width: 2)),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(height: (w - 44) / 2, width: double.infinity, child: Padding(padding: const EdgeInsets.all(6), child: AppImage(c.listImage, placeholder: const Color(0xFFF4F4F6)))),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                              child: Text(c.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(c.brand ?? (c.catText.isEmpty ? c.status : c.catText), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kGrayText)),
                            ),
                          ]),
                          Positioned(left: 6, top: 6, child: StatusBadge(c.status)),
                          if (multi) Positioned(right: 6, top: 6, child: Icon(s ? Icons.check_circle : Icons.radio_button_unchecked, color: s ? kPurple : Colors.black26)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
      bottomNavigationBar: multi && sel.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: const StadiumBorder(), foregroundColor: Colors.red),
                      onPressed: () async {
                        if (!await confirm(context, '删除', '确定删除选中的 ${sel.length} 件？', danger: true, ok: '删除')) return;
                        for (final id in sel) {
                          await AppDb.I.deleteClothes(id);
                        }
                        setState(() {
                          sel.clear();
                          multi = false;
                        });
                      },
                      child: Text('删除(${sel.length})'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: const StadiumBorder(), backgroundColor: kPurple),
                      onPressed: () async {
                        for (final id in sel) {
                          final c = all.firstWhere((e) => e.id == id);
                          c.status = '拥有';
                          await AppDb.I.saveClothes(c);
                        }
                        toast(null, '已加入衣橱（状态改为拥有）');
                        setState(() {
                          sel.clear();
                          multi = false;
                        });
                      },
                      child: Text('加入衣橱(${sel.length})'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}
