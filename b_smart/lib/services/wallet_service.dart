import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ledger_model.dart';
import '../models/account_details_model.dart';

/// Wallet service.
///
/// The new REST API does not yet expose wallet/transaction endpoints.
/// This service now operates independently of Supabase and will be wired
/// to REST endpoints once they are available.
class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;

  static const String _accountDetailsKey = 'wallet_account_details_v1';

  AccountDetails? _accountDetails;
  bool _hasLoadedAccountDetails = false;

  WalletService._internal();

  // Get current coin balance.
  // TODO: Wire to REST API when `/wallet/balance` endpoint is available.
  Future<int> getCoinBalance() async {
    // Stub – return 0 until wallet API exists.
    return 0;
  }

  // Get equivalent value (assuming 1 coin = $0.01)
  Future<double> getEquivalentValue() async {
    final balance = await getCoinBalance();
    return balance * 0.01;
  }

  // Get all transactions.
  Future<List<LedgerTransaction>> getTransactions() async {
    return [];
  }

  // Get filtered transactions
  Future<List<LedgerTransaction>> getFilteredTransactions({
    LedgerTransactionType? type,
    LedgerTransactionStatus? status,
  }) async {
    return [];
  }

  // Method to update balance.
  Future<void> updateBalance(int amount, String description) async {
    // TODO: Call REST API endpoint when available.
  }

  // Check if user has sufficient balance
  Future<bool> hasSufficientBalance(int amount) async {
    final balance = await getCoinBalance();
    return balance >= amount;
  }

  // Send gift coins to another user.
  Future<bool> sendGiftCoins(
      int amount, String recipientId, String recipientName) async {
    if (!await hasSufficientBalance(amount)) return false;
    // TODO: Call REST API endpoint when available.
    return false;
  }

  // Add coins via ledger (for ads/rewards).
  Future<bool> addCoinsViaLedger({
    required int amount,
    required String description,
    required String adId,
    Map<String, dynamic>? metadata,
  }) async {
    // TODO: Call REST API endpoint when available.
    return false;
  }

  // Returns cached account details if already loaded in-memory.
  AccountDetails? getAccountDetails() {
    return _accountDetails;
  }

  // Load account details from local storage.
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

  // Save account details to local storage.
  Future<bool> saveAccountDetails(AccountDetails details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(details.toJson());
      final ok = await prefs.setString(_accountDetailsKey, encoded);
      if (!ok) {
        return false;
      }
      _accountDetails = details;
      _hasLoadedAccountDetails = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  // Delete account details from local storage.
  Future<void> deleteAccountDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountDetailsKey);
    _accountDetails = null;
    _hasLoadedAccountDetails = true;
  }
}
