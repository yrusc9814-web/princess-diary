import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// 黑底全屏图片预览：左右滑动切换同一搭配的所有图片，双指放大，双击在 1x/2.5x 之间切换。
class ImagePreviewPage extends StatefulWidget {
  final List<String> images;
  final int initial;
  const ImagePreviewPage({super.key, required this.images, this.initial = 0});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late final PageController _pc = PageController(initialPage: _safeInitial);
  late int _index = _safeInitial;

  int get _safeInitial => widget.images.isEmpty ? 0 : widget.initial.clamp(0, widget.images.length - 1);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _pc,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ZoomImage(rel: widget.images[i]),
          ),
        ),
        // 顶部：当前/总数 + 关闭
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(12)),
                    child: Text('${_index + 1}/$total', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                const SizedBox(width: 8),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// 单张图：InteractiveViewer 双指缩放，双击在 1x / 2.5x 切换。
class _ZoomImage extends StatefulWidget {
  final String rel;
  const _ZoomImage({required this.rel});
  @override
  State<_ZoomImage> createState() => _ZoomImageState();
}

class _ZoomImageState extends State<_ZoomImage> {
  final _tc = TransformationController();
  static const _doubleTapScale = 2.5;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final s = _tc.value.getMaxScaleOnAxis();
    if (s > 1.05) {
      _tc.value = Matrix4.identity();
    } else {
      _tc.value = Matrix4.identity()..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 4,
        clipBehavior: Clip.none,
        child: Center(child: AppImage(widget.rel, fit: BoxFit.contain)),
      ),
    );
  }
}
