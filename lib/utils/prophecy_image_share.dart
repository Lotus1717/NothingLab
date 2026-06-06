import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// 将 [RepaintBoundary] 渲染为 PNG 并通过系统分享面板发出
Future<void> shareRepaintBoundaryAsImage(
  GlobalKey boundaryKey, {
  String fileName = 'nonsense_prophet.png',
}) async {
  final boundary = boundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('分享卡片尚未就绪');
  }

  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('图片生成失败');
  }

  final bytes = byteData.buffer.asUint8List();
  await Share.shareXFiles(
    [
      XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: fileName,
      ),
    ],
    subject: '废话预言家',
  );
}
