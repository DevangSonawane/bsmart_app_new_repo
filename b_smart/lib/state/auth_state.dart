import 'package:meta/meta.dart';

@immutable
class AuthState {
  final bool isAuthenticated;
  final String? userId;

  const AuthState({
    required this.isAuthenticated,
    this.userId,
  });

  factory AuthState.initial() {
    return const AuthState(isAuthenticated: false, userId: null);
  }

  AuthState copyWith({bool? isAuthenticated, String? userId}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
    );
  }
}

