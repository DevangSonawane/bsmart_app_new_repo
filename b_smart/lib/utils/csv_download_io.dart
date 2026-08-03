import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> saveCsvDownload({
  required String fileName,
  required String csvContent,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final safeName = fileName.trim().isEmpty ? 'bsmart-my-data.csv' : fileName;
  final file = File(p.join(directory.path, safeName));
  await file.writeAsString(csvContent, flush: true, encoding: utf8);

  try {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Your data export is ready.',
    );
  } catch (_) {
    // The file was still written successfully even if the share sheet fails.
  }

  return file.path;
}
