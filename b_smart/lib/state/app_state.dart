import 'package:meta/meta.dart';
import 'auth_state.dart';
import 'profile_state.dart';
import 'reels_state.dart';
import 'ads_state.dart';
import 'feed_state.dart';

@immutable
class AppState {
  final AuthState authState;
  final ProfileState profileState;
  final ReelsState reelsState;
  final AdsState adsState;
  final FeedState feedState;

  const AppState({
    required this.authState,
    required this.profileState,
    required this.reelsState,
    required this.adsState,
    required this.feedState,
  });

  factory AppState.initial() {
    return AppState(
      authState: AuthState.initial(),
      profileState: ProfileState.initial(),
      reelsState: ReelsState.initial(),
      adsState: AdsState.initial(),
      feedState: FeedState.initial(),
    );
  }

  AppState copyWith({AuthState? authState, ProfileState? profileState, ReelsState? reelsState, AdsState? adsState, FeedState? feedState}) {
    return AppState(
      authState: authState ?? this.authState,
      profileState: profileState ?? this.profileState,
      reelsState: reelsState ?? this.reelsState,
      adsState: adsState ?? this.adsState,
      feedState: feedState ?? this.feedState,
    );
  }
}
