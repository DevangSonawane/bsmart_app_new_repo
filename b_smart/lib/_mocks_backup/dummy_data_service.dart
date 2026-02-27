import '../models/user_model.dart';

class DummyDataService {
  static final DummyDataService _instance = DummyDataService._internal();
  factory DummyDataService() => _instance;
  DummyDataService._internal();

  User getCurrentUser() {
    return User(
      id: 'user-1',
      name: 'John Doe',
      email: 'john.doe@example.com',
      phone: '+1234567890',
      avatarUrl: null,
      isOnline: true,
      followers: 1250,
      following: 450,
      posts: 89,
      coins: 1250,
      bio: 'Digital creator | Tech enthusiast',
      address: 'New York, USA',
    );
  }

  List<User> getOnlineUsers() {
    return [
      User(
        id: 'user-2',
        name: 'Alice Smith',
        email: 'alice@example.com',
        avatarUrl: null,
        isOnline: true,
      ),
      User(
        id: 'user-3',
        name: 'Bob Johnson',
        email: 'bob@example.com',
        avatarUrl: null,
        isOnline: true,
      ),
    ];
  }
}

