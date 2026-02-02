import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> downloadFile(Uint8List bytes, String filename) async {
  final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes);
}
