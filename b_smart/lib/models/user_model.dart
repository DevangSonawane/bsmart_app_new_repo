class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isOnline;
  final int followers;
  final int following;
  final int posts;
  final int coins;
  final String? bio;
  final String? address;
  final String? username; // Added for auth
  final DateTime? dateOfBirth; // Added for auth
  final bool? isUnder18; // Added for auth

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.isOnline = false,
    this.followers = 0,
    this.following = 0,
    this.posts = 0,
    this.coins = 0,
    this.bio,
    this.address,
    this.username,
    this.dateOfBirth,
    this.isUnder18,
  });

  // Factory constructor to create User from AuthUser
  factory User.fromAuthUser(dynamic authUser, {
    int followers = 0,
    int following = 0,
    int posts = 0,
    int coins = 0,
    bool isOnline = false,
  }) {
    return User(
      id: authUser.id,
      name: authUser.fullName ?? authUser.username,
      email: authUser.email ?? '',
      phone: authUser.phone,
      avatarUrl: authUser.avatarUrl,
      username: authUser.username,
      dateOfBirth: authUser.dateOfBirth,
      isUnder18: authUser.isUnder18,
      bio: authUser.bio,
      followers: followers,
      following: following,
      posts: posts,
      coins: coins,
      isOnline: isOnline,
    );
  }
}
