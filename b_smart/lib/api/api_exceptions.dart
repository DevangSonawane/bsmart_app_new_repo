/// Base class for all REST API errors.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  ApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 400 – Bad Request (validation errors, duplicate user, etc.)
class BadRequestException extends ApiException {
  BadRequestException({required super.message, super.body}) : super(statusCode: 400);
}

/// 401 – Unauthorized (missing or expired token)
class UnauthorizedException extends ApiException {
  UnauthorizedException({super.message = 'Unauthorized', super.body}) : super(statusCode: 401);
}

/// 403 – Forbidden (not owner of the resource)
class ForbiddenException extends ApiException {
  ForbiddenException({super.message = 'Forbidden', super.body}) : super(statusCode: 403);
}

/// 404 – Not Found
class NotFoundException extends ApiException {
  NotFoundException({super.message = 'Not found', super.body}) : super(statusCode: 404);
}

/// 500 – Internal Server Error
class ServerException extends ApiException {
  ServerException({super.message = 'Internal server error', super.body}) : super(statusCode: 500);
}

/// Network-level failure (no connection, timeout, etc.)
class NetworkException implements Exception {
  final String message;
  NetworkException({this.message = 'Network error. Please check your connection.'});

  @override
  String toString() => 'NetworkException: $message';
}
