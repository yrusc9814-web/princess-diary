import 'package:flutter/material.dart';

import '../data/models.dart';
import 'common.dart';

/// 推荐搭配预览：按品类排布单品图（左列 外套/上装，右列 下装/鞋，配饰包袋小图）
class OutfitPreview extends StatelessWidget {
  final List<Clothes> items;
  final double height;
  const OutfitPreview(this.items, {super.key, this.height = 300});

  int _order(Clothes c) => switch (c.cat1) {
        '外套' => 0,
        '上装' => 1,
        '连衣裙' || '连体装' => 1,
        '下装' => 2,
        '鞋履' => 3,
        '包袋' => 4,
        _ => 5,
      };

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => _order(a).compareTo(_order(b)));
    final main = sorted.where((c) => _order(c) <= 2).toList();
    final side = sorted.where((c) => _order(c) > 2).toList();
    return SizedBox(
      height: height,
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(children: [
            for (final c in main) Expanded(child: Padding(padding: const EdgeInsets.all(4), child: AppImage(c.mainImage, width: double.infinity, placeholder: Colors.transparent))),
            if (main.isEmpty) const Spacer(),
          ]),
        ),
        if (side.isNotEmpty)
          Expanded(
            flex: 2,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final c in side.take(3))
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: AspectRatio(aspectRatio: 1, child: AppImage(c.mainImage, placeholder: Colors.transparent)),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}
