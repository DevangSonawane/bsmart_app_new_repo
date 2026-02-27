import 'package:redux/redux.dart';
import 'auth_state.dart';
import 'auth_actions.dart';

final authReducer = combineReducers<AuthState>([
  TypedReducer<AuthState, SetAuthenticated>(_setAuthenticated),
  TypedReducer<AuthState, ClearAuthentication>(_clearAuthentication),
]);

AuthState _setAuthenticated(AuthState state, SetAuthenticated action) {
  return state.copyWith(isAuthenticated: true, userId: action.userId);
}

AuthState _clearAuthentication(AuthState state, ClearAuthentication action) {
  return AuthState.initial();
}

