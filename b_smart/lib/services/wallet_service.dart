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

  AccountDetails? _accountDetails;

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

  // Get account details (Stub)
  AccountDetails? getAccountDetails() {
    return _accountDetails;
  }

  // Save account details (Stub)
  Future<bool> saveAccountDetails(AccountDetails details) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _accountDetails = details;
    return true;
  }

  // Delete account details (Stub)
  Future<void> deleteAccountDetails() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _accountDetails = null;
  }
}
