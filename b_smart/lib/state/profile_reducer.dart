import 'package:redux/redux.dart';
import 'profile_state.dart';
import 'profile_actions.dart';
import 'feed_actions.dart';

final profileReducer = combineReducers<ProfileState>([
  TypedReducer<ProfileState, SetProfile>(_setProfile).call,
  TypedReducer<ProfileState, ClearProfile>(_clearProfile).call,
  TypedReducer<ProfileState, AdjustFollowingCount>(_adjustFollowingCount).call,
  TypedReducer<ProfileState, RemovePost>(_removePost).call,
]);

ProfileState _setProfile(ProfileState state, SetProfile action) {
  return state.copyWith(profile: action.profile);
}

ProfileState _clearProfile(ProfileState state, ClearProfile action) {
  return ProfileState.initial();
}

ProfileState _adjustFollowingCount(ProfileState state, AdjustFollowingCount action) {
  final profile = state.profile;
  if (profile == null) return state;
  final next = Map<String, dynamic>.from(profile);
  final current = (next['following_count'] as int?) ?? 0;
  final updated =
      ((current + action.delta).toDouble().clamp(0, double.maxFinite)).toInt();
  next['following_count'] = updated;
  return state.copyWith(profile: next);
}

ProfileState _removePost(ProfileState state, RemovePost action) {
  final profile = state.profile;
  if (profile == null) return state;
  
  final next = Map<String, dynamic>.from(profile);
  
  // Update posts_count
  final currentCount = (next['posts_count'] as int?) ?? 0;
  if (currentCount > 0) {
    next['posts_count'] = currentCount - 1;
  }
  
  return state.copyWith(profile: next);
}
