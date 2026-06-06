import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<XFile> pngBytesToXFile(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final path = p.join(dir.path, fileName);
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return XFile(path, mimeType: 'image/png', name: fileName);
}
