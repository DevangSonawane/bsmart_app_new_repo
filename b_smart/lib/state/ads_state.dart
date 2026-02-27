import 'package:meta/meta.dart';

@immutable
class AdsState {
  final List<Map<String, dynamic>> ads;

  const AdsState({this.ads = const []});

  factory AdsState.initial() => const AdsState();

  AdsState copyWith({List<Map<String, dynamic>>? ads}) {
    return AdsState(ads: ads ?? this.ads);
  }
}

