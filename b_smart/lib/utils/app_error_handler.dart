import 'package:flutter/foundation.dart';

import '../api/api_exceptions.dart';

class AppErrorHandler {
  AppErrorHandler._();

  static String userMessage(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is ApiException) {
      return _fromApiException(error, fallback: fallback);
    }
    if (error is NetworkException) {
      return error.message;
    }

    final text = _extractMessage(error);
    return _sanitizeMessage(text, fallback: fallback);
  }

  static void logError(String context, Object error, [StackTrace? stackTrace]) {
    debugPrint('[$context] $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static String _fromApiException(
    ApiException error, {
    required String fallback,
  }) {
    final raw = error.message.trim();
    final lower = raw.toLowerCase();

    if (error.statusCode == 400) {
      if (lower.contains('duplicate') || lower.contains('already exists')) {
        return 'This item already exists.';
      }
      if (lower.contains('username')) {
        return 'That username is not available.';
      }
      if (lower.contains('email')) {
        return 'Please enter a valid email address.';
      }
      if (lower.contains('phone')) {
        return 'Please enter a valid phone number.';
      }
      if (lower.contains('password')) {
        return 'Please check your password and try again.';
      }
      return raw.isNotEmpty ? raw : 'Please check your input and try again.';
    }

    if (error.statusCode == 401) {
      return 'Please check your credentials and try again.';
    }
    if (error.statusCode == 403) {
      return 'You do not have permission to do that.';
    }
    if (error.statusCode == 404) {
      return 'We could not find that item.';
    }
    if (error.statusCode == 409) {
      return 'This item already exists.';
    }
    if (error.statusCode == 429) {
      return 'Too many attempts. Please wait and try again.';
    }
    if (error.statusCode >= 500) {
      return 'Our servers are having trouble right now. Please try again later.';
    }

    return raw.isNotEmpty ? raw : fallback;
  }

  static String _extractMessage(Object error) {
    var text = error.toString();
    text = text.replaceFirst(RegExp(r'^Exception:\s*'), '');
    text = text.replaceFirst(RegExp(r'^Error:\s*'), '');
    text = text.replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), '');
    text = text.replaceFirst(RegExp(r'^NetworkException:\s*'), '');
    final newline = text.indexOf('\n');
    if (newline >= 0) {
      text = text.substring(0, newline);
    }
    return text.trim();
  }

  static String _sanitizeMessage(
    String message, {
    required String fallback,
  }) {
    if (message.isEmpty) return fallback;
    final lower = message.toLowerCase();
    const technicalHints = [
      'stack trace',
      'apiexception(',
      'socketexception',
      'formatexception',
      'typeerror',
      'null check operator',
      'database',
      'internal server',
      'server error',
      'response body',
      'exception:',
    ];
    if (technicalHints.any(lower.contains)) return fallback;
    return message;
  }
}
