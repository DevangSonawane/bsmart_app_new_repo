import 'api_client.dart';

/// REST API wrapper for follow requests (private account approvals).
///
/// Backend implementations vary; this client is best-effort and tries a few
/// common routes + response shapes.
class FollowRequestsApi {
  static final FollowRequestsApi _instance = FollowRequestsApi._internal();
  factory FollowRequestsApi() => _instance;
  FollowRequestsApi._internal();

  final ApiClient _client = ApiClient();

  /// Toggle account privacy (public <-> private).
  ///
  /// Private -> Public: backend may auto-accept pending follow requests.
  Future<Map<String, dynamic>> toggleAccountPrivacy() async {
    final res = await _client.patch('/follow/privacy/toggle');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  /// Set account privacy explicitly.
  Future<Map<String, dynamic>> setAccountPrivacy(
      {required bool isPrivate}) async {
    final res = await _client
        .patch('/follow/privacy/set', body: {'isPrivate': isPrivate});
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<FollowPrivacyStatus?> getPrivacyStatus() async {
    final res = await _client.get('/follow/privacy/status');
    final map = res is Map<String, dynamic> ? res : null;
    final data =
        map?['data'] is Map ? Map<String, dynamic>.from(map!['data']) : null;
    final src = data ?? map;
    if (src == null) return null;

    final isPrivateRaw = src['isPrivate'] ?? src['is_private'];
    final isPrivate = isPrivateRaw == true ||
        (isPrivateRaw is String && isPrivateRaw.toLowerCase() == 'true');

    final countRaw = src['pendingRequestsCount'] ??
        src['pending_requests_count'] ??
        src['pendingCount'] ??
        src['pending_count'];
    final count = _toInt(countRaw);

    return FollowPrivacyStatus(
      isPrivate: isPrivate,
      pendingRequestsCount: count,
    );
  }

  Future<FollowRequestsPage> getFollowRequests() async {
    final res = await _client.get('/follow/requests');
    final map = res is Map<String, dynamic> ? res : null;
    final data =
        map?['data'] is Map ? Map<String, dynamic>.from(map!['data']) : null;
    final src = data ?? map ?? const <String, dynamic>{};

    final count = _toInt(src['count'] ?? src['total'] ?? src['pendingCount']);
    final raw = src['requests'] ?? src['items'] ?? src['data'];
    final list = (raw is List ? raw : const <dynamic>[])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final safeCount = count > 0 ? count : list.length;
    return FollowRequestsPage(count: safeCount, requests: list);
  }

  Future<void> acceptFollowRequest(String requesterId) async {
    final id = requesterId.trim();
    if (id.isEmpty) return;
    await _client.post('/follow/requests/$id/accept');
  }

  Future<void> declineFollowRequest(String requesterId) async {
    final id = requesterId.trim();
    if (id.isEmpty) return;
    await _client.post('/follow/requests/$id/decline');
  }

  Future<void> cancelFollowRequest(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    await _client.delete('/follow/request/$id/cancel');
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class FollowPrivacyStatus {
  final bool isPrivate;
  final int pendingRequestsCount;
  const FollowPrivacyStatus({
    required this.isPrivate,
    required this.pendingRequestsCount,
  });
}

class FollowRequestsPage {
  final int count;
  final List<Map<String, dynamic>> requests;
  const FollowRequestsPage({required this.count, required this.requests});
}
