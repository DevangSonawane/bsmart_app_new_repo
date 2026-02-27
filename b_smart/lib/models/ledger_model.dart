enum LedgerTransactionType {
  adReward,
  giftReceived,
  giftSent,
  payout,
  refund,
}

enum LedgerTransactionStatus {
  completed,
  pending,
  failed,
  blocked,
}

class LedgerTransaction {
  final String id;
  final String userId;
  final LedgerTransactionType type;
  final int amount; // Positive for credit, negative for debit
  final DateTime timestamp;
  final LedgerTransactionStatus status;
  final String? description;
  final String? relatedId; // Ad ID, transaction ID, etc.
  final Map<String, dynamic>? metadata; // Additional data

  LedgerTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.timestamp,
    this.status = LedgerTransactionStatus.pending,
    this.description,
    this.relatedId,
    this.metadata,
  });

  // Calculate balance from ledger transactions
  static int calculateBalance(List<LedgerTransaction> transactions) {
    return transactions
        .where((t) => t.status == LedgerTransactionStatus.completed)
        .fold(0, (sum, t) => sum + t.amount);
  }
}
