import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

Future<XFile> pngBytesToXFile(Uint8List bytes, String fileName) async {
  return XFile.fromData(
    bytes,
    mimeType: 'image/png',
    name: fileName,
  );
}
