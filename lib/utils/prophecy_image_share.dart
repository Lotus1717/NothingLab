import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import 'prophecy_share_xfile.dart';

/// 将 [RepaintBoundary] 渲染为 PNG 并通过系统分享面板发出
Future<void> shareRepaintBoundaryAsImage(
  GlobalKey boundaryKey, {
  String fileName = 'nonsense_prophet.png',
  Rect? sharePositionOrigin,
}) async {
  final boundary = boundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('分享卡片尚未就绪');
  }

  // 离屏卡片需多等一帧，确保本地字体与布局绘制完成
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;

  final image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    throw StateError('图片生成失败');
  }

  final bytes = byteData.buffer.asUint8List();
  final xFile = await pngBytesToXFile(bytes, fileName);

  final result = await Share.shareXFiles(
    [xFile],
    subject: '我的手机说我…',
    sharePositionOrigin: sharePositionOrigin,
    fileNameOverrides: [fileName],
  );

  if (result.status == ShareResultStatus.unavailable) {
    throw StateError('当前设备无法打开分享面板');
  }
}

/// iPad 分享需要非零锚点，否则可能报错
Rect defaultSharePositionOrigin(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return Rect.fromLTWH(
    size.width * 0.5 - 1,
    size.height * 0.75,
    2,
    2,
  );
}
