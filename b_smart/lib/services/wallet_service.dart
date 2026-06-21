import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../models/account_details_model.dart';
import '../models/ledger_model.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;

  static const String _accountDetailsKey = 'wallet_account_details_v1';
  static const String _localLedgerKey = 'wallet_local_ledger_v1';

  final AuthApi _authApi = AuthApi();
  final WalletApi _walletApi = WalletApi();

  AccountDetails? _accountDetails;
  bool _hasLoadedAccountDetails = false;

  WalletService._internal();

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

    final data =
        await _walletApi.memberHistory(userId: userId);
    final success = data['success'];
    if (success is bool && !success) {
      final message = data['message']?.toString() ?? 'Failed to load wallet data';
      throw Exception(message);
    }
    return data;
  }

  /// `GET /wallet/me` — current wallet + recent transactions (best-effort).
  Future<Map<String, dynamic>> fetchWalletMe({int? limit, int? page}) async {
    final data = await _walletApi.me(limit: limit, page: page);
    final success = data['success'];
    if (success is bool && !success) {
      final message = data['message']?.toString() ?? 'Failed to load wallet data';
      throw Exception(message);
    }
    return data;
  }

  /// `GET /wallet` — backend-dependent wallet response (best-effort).
  Future<Map<String, dynamic>> fetchWallet({int? limit, int? page}) async {
    final data = await _walletApi.wallet(limit: limit, page: page);
    final success = data['success'];
    if (success is bool && !success) {
      final message = data['message']?.toString() ?? 'Failed to load wallet data';
      throw Exception(message);
    }
    return data;
  }

  /// Mirrors React web app fallback balance logic (`/wallet/me` then `/wallet`).
  Future<int> fetchWalletBalance({int? limit}) async {
    return _walletApi.getBalance(limit: limit);
  }

  Future<int> getCoinBalance() async {
    try {
      final bal = await fetchWalletBalance(limit: 1);
      final local = await _getLocalAdRewardBalance();
      if (bal > 0) return bal + local;
      final data = await fetchMemberWalletHistoryForCurrentUser();
      dynamic wallet = data['wallet'];
      if (wallet == null && data['data'] is Map) {
        wallet = (data['data'] as Map)['wallet'];
      }
      if (wallet is Map) {
        final balance = wallet['balance'];
        if (balance is int) return balance + local;
        if (balance is num) return balance.toInt() + local;
        if (balance is String) return (int.tryParse(balance) ?? 0) + local;
      }
      return local;
    } catch (_) {
      return _getLocalAdRewardBalance();
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

      final remote = txRaw.map((raw) {
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

      final local = await _loadLocalLedger(userId: userId);
      final existingIds = remote.map((t) => t.id).toSet();
      final merged = <LedgerTransaction>[
        ...local.where((t) => !existingIds.contains(t.id)),
        ...remote,
      ];
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return merged;
    } catch (_) {
      final local = await _loadLocalLedger();
      local.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return local;
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
    final normalizedAmount = amount > 0 ? amount : 0;
    final normalizedAdId = adId.trim();
    final normalizedDescription = description.trim();
    if (normalizedAmount <= 0 || normalizedAdId.isEmpty || normalizedDescription.isEmpty) {
      return false;
    }

    final userId = await _resolveCurrentUserId();
    if (userId.isEmpty) return false;

    final ledger = await _loadLedgerEntries();
    final existing = ledger.any((entry) {
      return (entry['userId'] ?? '').toString() == userId &&
          (entry['relatedId'] ?? '').toString() == normalizedAdId &&
          (entry['type'] ?? '').toString() == 'AD_REWARD' &&
          (entry['status'] ?? '').toString() == 'COMPLETED';
    });
    if (existing) return true;

    ledger.add({
      'id': 'ledger-${DateTime.now().microsecondsSinceEpoch}',
      'userId': userId,
      'type': 'AD_REWARD',
      'amount': normalizedAmount,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'COMPLETED',
      'description': normalizedDescription,
      'relatedId': normalizedAdId,
      'metadata': metadata ?? <String, dynamic>{},
    });

    return _saveLedgerEntries(ledger);
  }

  Future<String> _resolveCurrentUserId() async {
    try {
      final meRaw = await _authApi.me();
      final profile = _normalizeProfile(meRaw);
      final userId = _extractUserId(profile);
      return userId.trim();
    } catch (_) {
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> _loadLedgerEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localLedgerKey);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> _saveLedgerEntries(List<Map<String, dynamic>> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.setString(_localLedgerKey, jsonEncode(entries));
    } catch (_) {
      return false;
    }
  }

  Future<List<LedgerTransaction>> _loadLocalLedger({String? userId}) async {
    final raw = await _loadLedgerEntries();
    final selectedUserId = userId?.trim();
    return raw
        .where((entry) {
          if (selectedUserId == null || selectedUserId.isEmpty) return true;
          return (entry['userId'] ?? '').toString() == selectedUserId;
        })
        .map((entry) {
          final timestampRaw = entry['timestamp']?.toString();
          final timestamp = timestampRaw == null
              ? DateTime.now()
              : DateTime.tryParse(timestampRaw) ?? DateTime.now();
          final amountRaw = entry['amount'];
          final amount = amountRaw is int
              ? amountRaw
              : amountRaw is num
                  ? amountRaw.toInt()
                  : int.tryParse(amountRaw?.toString() ?? '') ?? 0;
          final statusRaw = (entry['status'] ?? '').toString().toUpperCase();
          final status = statusRaw == 'COMPLETED'
              ? LedgerTransactionStatus.completed
              : statusRaw == 'FAILED'
                  ? LedgerTransactionStatus.failed
                  : statusRaw == 'BLOCKED'
                      ? LedgerTransactionStatus.blocked
                      : LedgerTransactionStatus.pending;
          final typeRaw = (entry['type'] ?? '').toString().toUpperCase();
          final type = typeRaw.contains('GIFT')
              ? LedgerTransactionType.giftReceived
              : typeRaw.contains('REFUND')
                  ? LedgerTransactionType.refund
                  : typeRaw.contains('PAYOUT')
                      ? LedgerTransactionType.payout
                      : LedgerTransactionType.adReward;
          return LedgerTransaction(
            id: (entry['id'] ?? timestamp.microsecondsSinceEpoch).toString(),
            userId: (entry['userId'] ?? '').toString(),
            type: type,
            amount: amount,
            timestamp: timestamp,
            status: status,
            description: entry['description']?.toString(),
            relatedId: entry['relatedId']?.toString(),
            metadata: entry['metadata'] is Map
                ? Map<String, dynamic>.from(entry['metadata'] as Map)
                : null,
          );
        })
        .where((tx) => tx.status == LedgerTransactionStatus.completed)
        .toList();
  }

  Future<int> _getLocalAdRewardBalance() async {
    final local = await _loadLocalLedger();
    return local.fold<int>(0, (sum, tx) => sum + tx.amount);
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
