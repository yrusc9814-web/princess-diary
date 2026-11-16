import 'dart:ui';

/// 裁剪框几何运算（0~1 归一化坐标，纯函数，方便单测）。

/// 以 [focal01] 为中心把 [base] 等比缩放 [scale] 倍，再平移 [pan01]。
///
/// 宽高同乘同一个系数，避免某一维先撞到边界时被压扁变形；缩放系数会被
/// 限制在“宽高都不小于 [minSize] 且都不大于 1”的范围内，最后整体平移回
/// [0,1] 区域。
Rect scaleCrop(Rect base, double scale, Offset focal01, Offset pan01, {double minSize = 0.08}) {
  final w = base.width <= 0 ? minSize : base.width;
  final h = base.height <= 0 ? minSize : base.height;
  final minK = minSize / (w < h ? w : h);
  final maxK = 1 / (w > h ? w : h);
  var k = scale;
  if (k < minK) k = minK;
  if (k > maxK) k = maxK;
  if (!k.isFinite) k = 1;
  final nw = (w * k).clamp(minSize, 1.0);
  final nh = (h * k).clamp(minSize, 1.0);
  // 焦点下的图像位置在缩放前后保持不动，再叠加本帧平移。
  final left = focal01.dx - (focal01.dx - base.left) * (nw / w) + pan01.dx;
  final top = focal01.dy - (focal01.dy - base.top) * (nh / h) + pan01.dy;
  return Rect.fromLTWH(left.clamp(0.0, 1.0 - nw), top.clamp(0.0, 1.0 - nh), nw, nh);
}

/// 平移裁剪框 [d01]，尺寸不变，越界时整体夹回 [0,1]。
Rect panCrop(Rect c, Offset d01) {
  final w = c.width.clamp(0.0, 1.0);
  final h = c.height.clamp(0.0, 1.0);
  final left = (c.left + d01.dx).clamp(0.0, 1.0 - w);
  final top = (c.top + d01.dy).clamp(0.0, 1.0 - h);
  return Rect.fromLTWH(left, top, w, h);
}
