import 'api_client.dart';
import 'api_exceptions.dart';

class PolicyDocument {
  final String type;
  final String title;
  final String content;

  const PolicyDocument({
    required this.type,
    required this.title,
    required this.content,
  });
}

class PolicyApi {
  PolicyApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<PolicyDocument> getPolicyByType(String type) async {
    final normalizedType = type.trim();
    if (normalizedType.isEmpty) {
      throw NotFoundException(message: 'Policy not found.');
    }

    final response = await _client.get(
      '/policies/app/member',
      queryParams: <String, String>{'type': normalizedType},
    );

    final payload = _firstPolicyMap(response);
    if (payload == null) {
      throw NotFoundException(message: 'Policy not found.');
    }

    final title = _readString(
      payload['title'] ?? payload['name'] ?? payload['policy_title'],
      fallback: normalizedType,
    );
    final content = _readString(
      payload['content'] ?? payload['html'] ?? payload['body'],
      fallback: '',
    );

    if (content.isEmpty) {
      throw NotFoundException(message: 'Policy not found.');
    }

    return PolicyDocument(
      type: normalizedType,
      title: title,
      content: content,
    );
  }

  Map<String, dynamic>? _firstPolicyMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        return Map<String, dynamic>.from(data.first);
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return response;
    }

    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first);
    }

    return null;
  }

  String _readString(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
