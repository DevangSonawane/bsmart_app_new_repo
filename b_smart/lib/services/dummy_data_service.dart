import '../models/user_model.dart';
import '../models/post_model.dart';

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
      User(
        id: 'user-4',
        name: 'Emma Wilson',
        email: 'emma@example.com',
        avatarUrl: null,
        isOnline: true,
      ),
      User(
        id: 'user-5',
        name: 'Mike Brown',
        email: 'mike@example.com',
        avatarUrl: null,
        isOnline: true,
      ),
      User(
        id: 'user-6',
        name: 'Sarah Davis',
        email: 'sarah@example.com',
        avatarUrl: null,
        isOnline: true,
      ),
    ];
  }

  List<Post> getFollowedUsersPosts() {
    return [
      Post(
        id: 'post-1',
        userId: 'user-2',
        userName: 'Alice Smith',
        imageUrl: null,
        caption: 'Beautiful sunset today! 🌅',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        likes: 245,
        comments: 12,
        isLiked: false,
      ),
      Post(
        id: 'post-2',
        userId: 'user-3',
        userName: 'Bob Johnson',
        imageUrl: null,
        caption: 'Working on something exciting! 💻',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        likes: 189,
        comments: 8,
        isLiked: true,
      ),
    ];
  }

  List<Post> getTaggedPosts() {
    return [
      Post(
        id: 'post-3',
        userId: 'user-4',
        userName: 'Emma Wilson',
        imageUrl: null,
        caption: 'Tagged you in this! @JohnDoe',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        likes: 156,
        comments: 5,
        isLiked: false,
        isTagged: true,
      ),
    ];
  }

  List<Post> getGeneralFeedPosts() {
    return [
      Post(
        id: 'post-4',
        userId: 'user-7',
        userName: 'David Lee',
        imageUrl: null,
        caption: 'Amazing day at the beach! 🏖️',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        likes: 320,
        comments: 15,
        isLiked: false,
      ),
      Post(
        id: 'post-5',
        userId: 'user-8',
        userName: 'Lisa Chen',
        imageUrl: null,
        caption: 'New recipe I tried today! 🍰',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        likes: 278,
        comments: 22,
        isLiked: true,
      ),
      Post(
        id: 'post-6',
        userId: 'user-9',
        userName: 'Tom Anderson',
        imageUrl: null,
        caption: 'Check out this amazing view! 🏔️',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        likes: 412,
        comments: 18,
        isLiked: false,
      ),
    ];
  }

  List<Post> getAds() {
    return [
      Post(
        id: 'ad-1',
        userId: 'advertiser-1',
        userName: 'Sponsored',
        imageUrl: null,
        caption: 'Discover amazing products!',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        likes: 0,
        comments: 0,
        isLiked: false,
        isAd: true,
        adTitle: 'Special Offer - 50% Off',
      ),
    ];
  }

  List<Reel> getReels() {
    return [
      Reel(
        id: 'reel-1',
        userId: 'user-10',
        userName: 'Reel Creator',
        videoUrl: 'dummy_video_url',
        caption: 'Amazing reel content!',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        likes: 1250,
        comments: 45,
        views: 5000,
        isLiked: false,
      ),
      Reel(
        id: 'reel-2',
        userId: 'user-11',
        userName: 'Product Showcase',
        videoUrl: 'dummy_video_url',
        caption: 'Check out this product!',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        likes: 890,
        comments: 32,
        views: 3200,
        isLiked: true,
        isPromotedProduct: true,
      ),
    ];
  }

  Future<List<User>> fetchOnlineUsers() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return getOnlineUsers();
  }

  Future<List<Post>> fetchFollowedUsersPosts() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return getFollowedUsersPosts();
  }

  Future<List<Post>> fetchTaggedPosts() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return getTaggedPosts();
  }

  Future<List<Post>> fetchGeneralFeed() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return getGeneralFeedPosts();
  }

  Future<List<Post>> fetchAds() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return getAds();
  }

  Future<List<Reel>> fetchReels() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return getReels();
  }
}
