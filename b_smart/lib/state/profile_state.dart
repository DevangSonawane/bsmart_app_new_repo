import 'package:meta/meta.dart';

@immutable
class ProfileState {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> posts;

  const ProfileState({this.profile, this.posts = const []});

  factory ProfileState.initial() => const ProfileState();

  ProfileState copyWith({Map<String, dynamic>? profile, List<Map<String, dynamic>>? posts}) {
    return ProfileState(profile: profile ?? this.profile, posts: posts ?? this.posts);
  }
}

