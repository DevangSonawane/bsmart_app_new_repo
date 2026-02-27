import 'package:meta/meta.dart';

@immutable
class ReelsState {
  final List<Map<String, dynamic>> reels;

  const ReelsState({this.reels = const []});

  factory ReelsState.initial() => const ReelsState();

  ReelsState copyWith({List<Map<String, dynamic>>? reels}) {
    return ReelsState(reels: reels ?? this.reels);
  }
}

