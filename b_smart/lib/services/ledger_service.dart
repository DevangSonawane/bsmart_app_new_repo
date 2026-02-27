import '../models/ledger_model.dart';

class LedgerService {
  static final LedgerService _instance = LedgerService._internal();
  factory LedgerService() => _instance;

  // Immutable ledger - all transactions stored here
  List<LedgerTransaction> _ledger = [];

  LedgerService._internal() {
    _ledger = _generateInitialLedger();
  }

  List<LedgerTransaction> _generateInitialLedger() {
    final now = DateTime.now();
    return [
      LedgerTransaction(
        id: 'ledger-1',
        userId: 'user-1',
        type: LedgerTransactionType.adReward,
        amount: 50,
        timestamp: now.subtract(const Duration(hours: 2)),
        status: LedgerTransactionStatus.completed,
        description: 'Watched Ad: Special Offer',
        relatedId: 'ad-1',
      ),
      LedgerTransaction(
        id: 'ledger-2',
        userId: 'user-1',
        type: LedgerTransactionType.giftReceived,
        amount: 100,
        timestamp: now.subtract(const Duration(days: 1)),
        status: LedgerTransactionStatus.completed,
        description: 'Gift from Alice Smith',
        relatedId: 'user-2',
      ),
      LedgerTransaction(
        id: 'ledger-3',
        userId: 'user-1',
        type: LedgerTransactionType.adReward,
        amount: 50,
        timestamp: now.subtract(const Duration(days: 1, hours: 5)),
        status: LedgerTransactionStatus.completed,
        description: 'Watched Ad: Product Launch',
        relatedId: 'ad-2',
      ),
      LedgerTransaction(
        id: 'ledger-4',
        userId: 'user-1',
        type: LedgerTransactionType.giftSent,
        amount: -75,
        timestamp: now.subtract(const Duration(days: 2)),
        status: LedgerTransactionStatus.completed,
        description: 'Gift to Bob Johnson',
        relatedId: 'user-3',
      ),
    ];
  }

  // Add transaction to ledger (immutable)
  LedgerTransaction addTransaction({
    required String userId,
    required LedgerTransactionType type,
    required int amount,
    String? description,
    String? relatedId,
    Map<String, dynamic>? metadata,
  }) {
    final transaction = LedgerTransaction(
      id: 'ledger-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: type,
      amount: amount,
      timestamp: DateTime.now(),
      status: LedgerTransactionStatus.pending,
      description: description,
      relatedId: relatedId,
      metadata: metadata,
    );

    _ledger.insert(0, transaction); // Add to beginning (latest first)
    return transaction;
  }

  // Update transaction status
  void updateTransactionStatus(
    String transactionId,
    LedgerTransactionStatus status,
  ) {
    final index = _ledger.indexWhere((t) => t.id == transactionId);
    if (index != -1) {
      final transaction = _ledger[index];
      _ledger[index] = LedgerTransaction(
        id: transaction.id,
        userId: transaction.userId,
        type: transaction.type,
        amount: transaction.amount,
        timestamp: transaction.timestamp,
        status: status,
        description: transaction.description,
        relatedId: transaction.relatedId,
        metadata: transaction.metadata,
      );
    }
  }

  // Get all transactions for a user
  List<LedgerTransaction> getUserTransactions(String userId) {
    return _ledger.where((t) => t.userId == userId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Get filtered transactions
  List<LedgerTransaction> getFilteredTransactions({
    required String userId,
    LedgerTransactionType? type,
    LedgerTransactionStatus? status,
  }) {
    var transactions = _ledger.where((t) => t.userId == userId);

    if (type != null) {
      transactions = transactions.where((t) => t.type == type);
    }

    if (status != null) {
      transactions = transactions.where((t) => t.status == status);
    }

    return transactions.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Calculate balance from ledger (CRITICAL: Balance is always calculated, never stored)
  int calculateBalance(String userId) {
    final userTransactions = getUserTransactions(userId);
    return LedgerTransaction.calculateBalance(userTransactions);
  }

  // Get transaction by ID
  LedgerTransaction? getTransaction(String transactionId) {
    try {
      return _ledger.firstWhere((t) => t.id == transactionId);
    } catch (e) {
      return null;
    }
  }

  // Get all ledger entries (for admin/audit)
  List<LedgerTransaction> getAllTransactions() {
    return List.from(_ledger)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}
