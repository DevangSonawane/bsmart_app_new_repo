import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/page_cache_service.dart';
import '../services/wallet_service.dart';
import '../models/ledger_model.dart';
import '../theme/instagram_theme.dart';
import '../utils/current_user.dart';

class CoinsHistoryScreen extends StatefulWidget {
  const CoinsHistoryScreen({super.key});

  @override
  State<CoinsHistoryScreen> createState() => _CoinsHistoryScreenState();
}

class _CoinsHistoryScreenState extends State<CoinsHistoryScreen> {
  final WalletService _walletService = WalletService();
  final PageCacheService _pageCache = PageCacheService();
  List<LedgerTransaction> _transactions = [];
  LedgerTransactionType? _selectedType;
  LedgerTransactionStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions({bool forceNetwork = false}) async {
    final currentUserId = await CurrentUser.id;
    final cacheParams = <String, dynamic>{
      if (_selectedType != null) 'type': _selectedType!.name,
      if (_selectedStatus != null) 'status': _selectedStatus!.name,
    };
    final cached = forceNetwork
        ? null
        : await _pageCache.get('coins_history', currentUserId ?? '', cacheParams);

    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        final transactions = decoded.map((item) {
          final map = item as Map<String, dynamic>;
          return LedgerTransaction(
            id: map['id'] as String? ?? '',
            userId: map['user_id'] as String? ?? '',
            type: LedgerTransactionType.values.firstWhere(
              (e) => e.name == (map['type'] as String? ?? 'adReward'),
              orElse: () => LedgerTransactionType.adReward,
            ),
            amount: (map['amount'] is int)
                ? map['amount'] as int
                : int.tryParse(map['amount'].toString()) ?? 0,
            timestamp: DateTime.tryParse(
                  map['timestamp'] as String? ?? '',
                ) ??
                DateTime.now(),
            status: LedgerTransactionStatus.values.firstWhere(
              (e) => e.name == (map['status'] as String? ?? 'pending'),
              orElse: () => LedgerTransactionStatus.pending,
            ),
            description: map['description'] as String?,
            relatedId: map['related_id'] as String?,
          );
        }).toList();
        if (mounted) {
          setState(() {
            _transactions = transactions;
          });
        }
        return;
      } on Exception catch (_) {
        await _pageCache.invalidate('coins_history', currentUserId ?? '');
      }
    }

    final transactions = (_selectedType != null || _selectedStatus != null)
        ? await _walletService.getFilteredTransactions(
            type: _selectedType,
            status: _selectedStatus,
          )
        : await _walletService.getTransactions();

    if (mounted) {
      setState(() {
        _transactions = transactions;
      });
    }

    try {
      await _pageCache.set(
        'coins_history',
        currentUserId ?? '',
        cacheParams,
        jsonEncode(
          transactions.map((t) => <String, dynamic>{
            'id': t.id,
            'user_id': t.userId,
            'type': t.type.name,
            'amount': t.amount,
            'timestamp': t.timestamp.toIso8601String(),
            'status': t.status.name,
            'description': t.description,
            'related_id': t.relatedId,
          }).toList(),
        ),
      );
    } on Exception catch (_) {}
  }

  IconData _getTransactionIcon(LedgerTransactionType type) {
    switch (type) {
      case LedgerTransactionType.adReward:
        return Icons.play_circle_outline;
      case LedgerTransactionType.giftReceived:
        return Icons.card_giftcard;
      case LedgerTransactionType.giftSent:
        return Icons.send;
      case LedgerTransactionType.payout:
        return Icons.money_off;
      case LedgerTransactionType.refund:
        return Icons.restore;
    }
  }

  Color _getTransactionColor(LedgerTransactionType type) {
    switch (type) {
      case LedgerTransactionType.adReward:
        return Colors.blue;
      case LedgerTransactionType.giftReceived:
        return Colors.green;
      case LedgerTransactionType.giftSent:
        return Colors.pink;
      case LedgerTransactionType.payout:
        return Colors.orange;
      case LedgerTransactionType.refund:
        return Colors.purple;
    }
  }

  String _getTransactionTypeLabel(LedgerTransactionType type) {
    switch (type) {
      case LedgerTransactionType.adReward:
        return 'Spotlight Reward';
      case LedgerTransactionType.giftReceived:
        return 'Gift Received';
      case LedgerTransactionType.giftSent:
        return 'Gift Sent';
      case LedgerTransactionType.payout:
        return 'Payout';
      case LedgerTransactionType.refund:
        return 'Refund';
    }
  }

  Color _getStatusColor(LedgerTransactionStatus status) {
    switch (status) {
      case LedgerTransactionStatus.completed:
        return Colors.green;
      case LedgerTransactionStatus.pending:
        return Colors.orange;
      case LedgerTransactionStatus.failed:
        return Colors.red;
      case LedgerTransactionStatus.blocked:
        return Colors.grey;
    }
  }

  String _normalizeDescription(LedgerTransaction transaction) {
    final raw = transaction.description?.trim() ?? '';
    if (raw.isEmpty) return raw;

    switch (transaction.type) {
      case LedgerTransactionType.adReward:
        return raw
            .replaceAll(RegExp(r'\b[Aa]d\b'), 'Spotlight')
            .replaceAll(RegExp(r'\b[Aa]ds\b'), 'Spotlights');
      case LedgerTransactionType.giftReceived:
      case LedgerTransactionType.giftSent:
      case LedgerTransactionType.payout:
      case LedgerTransactionType.refund:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('bCoins History'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                      _buildFilterChip(
                        'All Types',
                        _selectedType == null,
                        () {
                          setState(() {
                            _selectedType = null;
                            _loadTransactions();
                          });
                        },
                      ),
                      _buildFilterChip(
                        'Spotlight bCoins',
                        _selectedType == LedgerTransactionType.adReward,
                        () {
                          setState(() {
                            _selectedType = LedgerTransactionType.adReward;
                            _loadTransactions();
                          });
                        },
                      ),
                      _buildFilterChip(
                        'Gifts',
                        _selectedType == LedgerTransactionType.giftReceived ||
                            _selectedType == LedgerTransactionType.giftSent,
                        () {
                          setState(() {
                            _selectedType = LedgerTransactionType.giftReceived;
                            _loadTransactions();
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _transactions.isEmpty
                ? const Center(
                    child: Text('No transactions found'),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      _loadTransactions(forceNetwork: true);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _transactions[index];
                        final isPositive = transaction.amount > 0;
                        final iconColor =
                            _getTransactionColor(transaction.type);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getTransactionIcon(transaction.type),
                                color: iconColor,
                              ),
                            ),
                            title: Text(
                              _getTransactionTypeLabel(transaction.type),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (transaction.description != null)
                                  Text(_normalizeDescription(transaction)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          transaction.status,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        transaction.status.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _getStatusColor(
                                            transaction.status,
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(transaction.timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Text(
                              '${isPositive ? '+' : ''}${transaction.amount}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isPositive ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.amber,
      checkmarkColor: Colors.white,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
