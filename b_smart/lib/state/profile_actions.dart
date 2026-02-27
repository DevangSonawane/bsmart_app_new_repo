class SetProfile {
  final Map<String, dynamic> profile;
  SetProfile(this.profile);
}

class ClearProfile {}

class AdjustFollowingCount {
  final int delta;
  AdjustFollowingCount(this.delta);
}
