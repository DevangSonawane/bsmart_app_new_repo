import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ReelDraftData {
  final String id;
  final DateTime createdAt;
  final List<String> clipPaths;
  final String? audioPath;
  final String? voicePath;

  const ReelDraftData({
    required this.id,
    required this.createdAt,
    required this.clipPaths,
    this.audioPath,
    this.voicePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'clipPaths': clipPaths,
      'audioPath': audioPath,
      'voicePath': voicePath,
    };
  }

  static ReelDraftData fromJson(Map<String, dynamic> json) {
    return ReelDraftData(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      clipPaths: List<String>.from(json['clipPaths'] as List),
      audioPath: json['audioPath'] as String?,
      voicePath: json['voicePath'] as String?,
    );
  }
}

class ReelDraftService {
  Future<void> saveDraft(ReelDraftData draft) async {
    final dir = await _draftDir();
    final file = File('${dir.path}/${draft.id}.json');
    await file.writeAsString(jsonEncode(draft.toJson()), flush: true);
  }

  Future<ReelDraftData?> loadDraft(String draftId) async {
    final dir = await _draftDir();
    final file = File('${dir.path}/$draftId.json');
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    return ReelDraftData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<List<ReelDraftData>> listDrafts() async {
    final dir = await _draftDir();
    if (!await dir.exists()) return [];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final out = <ReelDraftData>[];
    for (final f in files) {
      final raw = await f.readAsString();
      out.add(ReelDraftData.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    }
    return out;
  }

  Future<Directory> _draftDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/reel_drafts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
