enum AccountType {
  regular,
  creator,
  business,
}

enum SponsoredVideoStatus {
  draft,
  underReview,
  approved,
  rejected,
  live,
  paused,
}

class UserAccount {
  final String userId;
  final AccountType accountType;
  final bool canCreateAds;
  final bool adAccountVerified;
  final bool paymentVerified;
  final bool emailVerified;
  final bool phoneVerified;
  final int followers;
  final int engagementScore;
  final bool hasPolicyViolations;
  final String? paymentMethodId;
  final String? productCatalogId;

  UserAccount({
    required this.userId,
    this.accountType = AccountType.regular,
    this.canCreateAds = false,
    this.adAccountVerified = false,
    this.paymentVerified = false,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.followers = 0,
    this.engagementScore = 0,
    this.hasPolicyViolations = false,
    this.paymentMethodId,
    this.productCatalogId,
  });

  bool get isEligibleForSponsoredContent {
    if (accountType == AccountType.regular) return false;
    if (hasPolicyViolations) return false;
    if (!adAccountVerified) return false;
    if (accountType == AccountType.creator) {
      // Creator requirements
      if (!emailVerified || !phoneVerified) return false;
      if (followers < 1000) return false; // Configurable minimum
    }
    return true;
  }
}

class SponsoredVideo {
  final String id;
  final String userId;
  final String? videoUrl;
  final String? thumbnailUrl;
  final List<String> productImageUrls;
  final String productName;
  final String productDescription;
  final double? price;
  final String? currency;
  final double? discount;
  final String? productCategory;
  final String brandName;
  final String productUrl;
  final String? sku;
  final String? variant;
  final DateTime? offerValidity;
  final String? affiliateId;
  final SponsoredVideoStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? campaignId;

  SponsoredVideo({
    required this.id,
    required this.userId,
    this.videoUrl,
    this.thumbnailUrl,
    this.productImageUrls = const [],
    required this.productName,
    required this.productDescription,
    this.price,
    this.currency,
    this.discount,
    this.productCategory,
    required this.brandName,
    required this.productUrl,
    this.sku,
    this.variant,
    this.offerValidity,
    this.affiliateId,
    this.status = SponsoredVideoStatus.draft,
    this.rejectionReason,
    required this.createdAt,
    this.submittedAt,
    this.approvedAt,
    this.campaignId,
  });
}
