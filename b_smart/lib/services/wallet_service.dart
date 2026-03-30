import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../models/account_details_model.dart';
import '../models/ledger_model.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;

  static const String _accountDetailsKey = 'wallet_account_details_v1';

  final ApiClient _apiClient = ApiClient();
  final AuthApi _authApi = AuthApi();

  AccountDetails? _accountDetails;
  bool _hasLoadedAccountDetails = false;

  WalletService._internal();

  Future<Map<String, dynamic>> _normalizeMap(dynamic raw) async {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String _extractUserId(Map<String, dynamic> profile) {
    final id = profile['id'] ?? profile['_id'] ?? profile['user_id'];
    return id?.toString() ?? '';
  }

  Map<String, dynamic> _normalizeProfile(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    if (map['user'] is Map) {
      return Map<String, dynamic>.from(map['user'] as Map);
    }
    if (map['data'] is Map) {
      final data = Map<String, dynamic>.from(map['data'] as Map);
      if (data['user'] is Map) {
        return Map<String, dynamic>.from(data['user'] as Map);
      }
      return data;
    }
    return map;
  }

  LedgerTransactionType _mapType(String rawType, String direction) {
    final t = rawType.toUpperCase();
    if (t.contains('GIFT') && direction == 'credit') {
      return LedgerTransactionType.giftReceived;
    }
    if (t.contains('GIFT') && direction == 'debit') {
      return LedgerTransactionType.giftSent;
    }
    if (t.contains('REFUND')) return LedgerTransactionType.refund;
    if (direction == 'debit') return LedgerTransactionType.payout;
    return LedgerTransactionType.adReward;
  }

  LedgerTransactionStatus _mapStatus(String rawStatus) {
    final s = rawStatus.toUpperCase();
    if (s == 'SUCCESS' || s == 'COMPLETED') {
      return LedgerTransactionStatus.completed;
    }
    if (s == 'FAILED') return LedgerTransactionStatus.failed;
    if (s == 'BLOCKED') return LedgerTransactionStatus.blocked;
    return LedgerTransactionStatus.pending;
  }

  Future<Map<String, dynamic>> fetchMemberWalletHistoryForCurrentUser() async {
    final meRaw = await _authApi.me();
    final profile = _normalizeProfile(meRaw);
    final userId = _extractUserId(profile);
    if (userId.isEmpty) {
      throw Exception('Could not resolve current user id');
    }

    final raw = await _apiClient.get('/wallet/member/$userId/history');
    final data = await _normalizeMap(raw);
    final success = data['success'];
    if (success is bool && !success) {
      final message = data['message']?.toString() ?? 'Failed to load wallet data';
      throw Exception(message);
    }
    return data;
  }

  Future<int> getCoinBalance() async {
    try {
      final data = await fetchMemberWalletHistoryForCurrentUser();
      dynamic wallet = data['wallet'];
      if (wallet == null && data['data'] is Map) {
        wallet = (data['data'] as Map)['wallet'];
      }
      if (wallet is Map) {
        final balance = wallet['balance'];
        if (balance is int) return balance;
        if (balance is num) return balance.toInt();
        if (balance is String) return int.tryParse(balance) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<double> getEquivalentValue() async {
    final balance = await getCoinBalance();
    return balance * 0.01;
  }

  Future<List<LedgerTransaction>> getTransactions() async {
    try {
      final data = await fetchMemberWalletHistoryForCurrentUser();
      final txRaw = data['transactions'];
      if (txRaw is! List) return <LedgerTransaction>[];

      final meRaw = await _authApi.me();
      final profile = _normalizeProfile(meRaw);
      final userId = _extractUserId(profile);

      return txRaw.map((raw) {
        final map = raw is Map<String, dynamic>
            ? raw
            : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
        final direction = (map['direction'] ?? '').toString().toLowerCase();
        final rawType = (map['type'] ?? 'UNKNOWN').toString();
        final rawAmount = map['amount'];
        int amount = 0;
        if (rawAmount is int) amount = rawAmount;
        if (rawAmount is num) amount = rawAmount.toInt();
        if (rawAmount is String) amount = int.tryParse(rawAmount) ?? 0;
        if (direction == 'debit' && amount > 0) amount = -amount;
        if (direction == 'credit' && amount < 0) amount = amount.abs();

        final createdAt = map['created_at']?.toString();
        final timestamp = createdAt != null
            ? DateTime.tryParse(createdAt) ?? DateTime.now()
            : DateTime.now();

        return LedgerTransaction(
          id: (map['_id'] ?? map['id'] ?? timestamp.millisecondsSinceEpoch).toString(),
          userId: userId,
          type: _mapType(rawType, direction),
          amount: amount,
          timestamp: timestamp,
          status: _mapStatus((map['status'] ?? '').toString()),
          description: map['description']?.toString() ?? map['label']?.toString(),
          relatedId: map['ad_id']?.toString(),
          metadata: map,
        );
      }).toList();
    } catch (_) {
      return <LedgerTransaction>[];
    }
  }

  Future<List<LedgerTransaction>> getFilteredTransactions({
    LedgerTransactionType? type,
    LedgerTransactionStatus? status,
  }) async {
    var items = await getTransactions();
    if (type != null) {
      items = items.where((t) => t.type == type).toList();
    }
    if (status != null) {
      items = items.where((t) => t.status == status).toList();
    }
    return items;
  }

  Future<void> updateBalance(int amount, String description) async {
    // Not yet exposed by backend.
  }

  Future<bool> hasSufficientBalance(int amount) async {
    final balance = await getCoinBalance();
    return balance >= amount;
  }

  Future<bool> sendGiftCoins(
      int amount, String recipientId, String recipientName) async {
    // Not yet exposed by backend.
    return false;
  }

  Future<bool> addCoinsViaLedger({
    required int amount,
    required String description,
    required String adId,
    Map<String, dynamic>? metadata,
  }) async {
    // Not yet exposed by backend.
    return false;
  }

  AccountDetails? getAccountDetails() {
    return _accountDetails;
  }

  Future<AccountDetails?> loadAccountDetails() async {
    if (_hasLoadedAccountDetails) {
      return _accountDetails;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountDetailsKey);
    if (raw == null || raw.isEmpty) {
      _accountDetails = null;
      _hasLoadedAccountDetails = true;
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _accountDetails = AccountDetails.fromJson(json);
    } catch (_) {
      _accountDetails = null;
    }
    _hasLoadedAccountDetails = true;
    return _accountDetails;
  }

  Future<bool> saveAccountDetails(AccountDetails details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(details.toJson());
      final ok = await prefs.setString(_accountDetailsKey, encoded);
      if (!ok) return false;
      _accountDetails = details;
      _hasLoadedAccountDetails = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteAccountDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountDetailsKey);
    _accountDetails = null;
    _hasLoadedAccountDetails = true;
  }
}
