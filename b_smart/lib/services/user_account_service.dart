import '../models/user_account_model.dart';

class UserAccountService {
  static final UserAccountService _instance = UserAccountService._internal();
  factory UserAccountService() => _instance;

  final Map<String, UserAccount> _accounts = {};
  final String _currentUserId = 'user-1';

  UserAccountService._internal() {
    _initializeAccounts();
  }

  void _initializeAccounts() {
    // Current user - Regular account
    _accounts[_currentUserId] = UserAccount(
      userId: _currentUserId,
      accountType: AccountType.regular,
      emailVerified: true,
      phoneVerified: true,
      followers: 1250,
      engagementScore: 85,
    );

    // Creator account example
    _accounts['creator-1'] = UserAccount(
      userId: 'creator-1',
      accountType: AccountType.creator,
      canCreateAds: true,
      adAccountVerified: true,
      paymentVerified: true,
      emailVerified: true,
      phoneVerified: true,
      followers: 5000,
      engagementScore: 92,
      paymentMethodId: 'payment-1',
    );

    // Business account example
    _accounts['business-1'] = UserAccount(
      userId: 'business-1',
      accountType: AccountType.business,
      canCreateAds: true,
      adAccountVerified: true,
      paymentVerified: true,
      emailVerified: true,
      phoneVerified: true,
      followers: 10000,
      engagementScore: 95,
      paymentMethodId: 'payment-2',
      productCatalogId: 'catalog-1',
    );
  }

  UserAccount? getAccount(String userId) {
    return _accounts[userId];
  }

  UserAccount getCurrentAccount() {
    return _accounts[_currentUserId] ?? UserAccount(userId: _currentUserId);
  }

  bool canCreateSponsoredContent(String userId) {
    final account = _accounts[userId];
    if (account == null) return false;
    return account.isEligibleForSponsoredContent;
  }

  Future<bool> upgradeToCreator(String userId) async {
    final account = _accounts[userId];
    if (account == null) return false;

    // Check requirements
    if (!account.emailVerified || !account.phoneVerified) {
      return false; // Missing verification
    }

    if (account.followers < 1000) {
      return false; // Not enough followers
    }

    if (account.hasPolicyViolations) {
      return false; // Has violations
    }

    // Upgrade account
    _accounts[userId] = UserAccount(
      userId: account.userId,
      accountType: AccountType.creator,
      canCreateAds: false, // Still needs approval
      adAccountVerified: false, // Needs approval
      paymentVerified: account.paymentVerified,
      emailVerified: account.emailVerified,
      phoneVerified: account.phoneVerified,
      followers: account.followers,
      engagementScore: account.engagementScore,
      hasPolicyViolations: account.hasPolicyViolations,
      paymentMethodId: account.paymentMethodId,
      productCatalogId: account.productCatalogId,
    );

    return true;
  }

  Future<bool> upgradeToBusiness(String userId) async {
    final account = _accounts[userId];
    if (account == null) return false;

    // Business accounts need payment verification
    if (!account.paymentVerified) {
      return false;
    }

    // Upgrade account
    _accounts[userId] = UserAccount(
      userId: account.userId,
      accountType: AccountType.business,
      canCreateAds: true, // Business gets immediate access
      adAccountVerified: true,
      paymentVerified: account.paymentVerified,
      emailVerified: account.emailVerified,
      phoneVerified: account.phoneVerified,
      followers: account.followers,
      engagementScore: account.engagementScore,
      hasPolicyViolations: account.hasPolicyViolations,
      paymentMethodId: account.paymentMethodId,
      productCatalogId: account.productCatalogId,
    );

    return true;
  }

  Future<bool> verifyAdAccount(String userId) async {
    final account = _accounts[userId];
    if (account == null) return false;

    _accounts[userId] = UserAccount(
      userId: account.userId,
      accountType: account.accountType,
      canCreateAds: true,
      adAccountVerified: true,
      paymentVerified: account.paymentVerified,
      emailVerified: account.emailVerified,
      phoneVerified: account.phoneVerified,
      followers: account.followers,
      engagementScore: account.engagementScore,
      hasPolicyViolations: account.hasPolicyViolations,
      paymentMethodId: account.paymentMethodId,
      productCatalogId: account.productCatalogId,
    );

    return true;
  }
}
