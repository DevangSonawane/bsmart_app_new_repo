// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

Future<String> saveCsvDownload({
  required String fileName,
  required String csvContent,
}) async {
  final blob = html.Blob(
    [utf8.encode(csvContent)],
    'text/csv;charset=utf-8',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
  return fileName;
}
