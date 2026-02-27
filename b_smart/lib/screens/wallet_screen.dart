import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/wallet_service.dart';
import '../models/account_details_model.dart';
import '../theme/instagram_theme.dart';
import '../theme/design_tokens.dart';
import '../widgets/clay_container.dart';
import 'coins_history_screen.dart';
import 'account_details_screen.dart';
import '../models/ledger_model.dart';
enum _HistoryState { hidden, minimal, expanded }
enum _MenuSection { none, accountDetails, redeem, help }
enum _TransactionQuickFilter { all, earned, spent, expired }

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with TickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  int _coinBalance = 0;
  double _equivalentValue = 0;
  bool _isLifeTime = true;
  int _totalEarnedLifetime = 0;
  int _totalSpentLifetime = 0;
  int _totalEarnedMonth = 0;
  int _totalSpentMonth = 0;
  bool _historyExpanded = false;
  List<LedgerTransaction> _transactions = [];
  DateTime? _filterStart;
  DateTime? _filterEnd;
  LedgerTransactionType? _filterType;
  String _coinsComparator = 'any'; // any, =, >=, <=
  int? _coinsValue;
  _HistoryState _historyState = _HistoryState.hidden;
  _MenuSection _menuOpen = _MenuSection.none;
  _TransactionQuickFilter _transactionQuickFilter = _TransactionQuickFilter.all;
  final _nameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ifscController = TextEditingController();
  String _selectedPaymentMethod = 'UPI';
  bool _isSavingDetails = false;
  AccountDetails? _existingDetails;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _seedTransactions();
    _loadAccountDetails();
  }

  Future<void> _loadBalance() async {
    final balance = await _walletService.getCoinBalance();
    final value = await _walletService.getEquivalentValue();
    if (mounted) {
      setState(() {
        _coinBalance = balance;
        _equivalentValue = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadBalance();
        },
        color: InstagramTheme.primaryPink,
        backgroundColor: InstagramTheme.surfaceWhite,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: DesignTokens.instaGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.badgePercent, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text(
                              'Available Balance',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Life Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Switch(
                              value: _isLifeTime,
                              onChanged: (v) => setState(() => _isLifeTime = v),
                              activeThumbColor: Colors.white,
                              activeTrackColor: Colors.white.withValues(alpha: 0.3),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (!_isLifeTime)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _monthName(DateTime.now().month),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _coinBalance.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('coins', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Earned', style: TextStyle(color: Colors.white)),
                            Text(
                              (_isLifeTime ? _totalEarnedLifetime : _totalEarnedMonth).toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Spent', style: TextStyle(color: Colors.white)),
                            Text(
                              (_isLifeTime ? _totalSpentLifetime : _totalSpentMonth).toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _buildTransactionSection(),

              const SizedBox(height: 24),

              // Menu Options
              _buildMenuSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ClayButton(
      onPressed: onTap,
      color: InstagramTheme.surfaceWhite,
      child: Column(
        children: [
          Icon(icon, size: 32, color: InstagramTheme.primaryPink),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: InstagramTheme.textBlack,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: InstagramTheme.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Account Details',
          subtitle: 'Manage payout account',
          section: _MenuSection.accountDetails,
          buildContent: () => _buildAccountDetailsInline(),
        ),
        _buildMenuItem(
          icon: Icons.redeem_outlined,
          title: 'Redeem Coins',
          subtitle: 'Use coins for orders',
          section: _MenuSection.redeem,
          buildContent: () => _buildRedeemInline(),
        ),
        _buildMenuItem(
          icon: Icons.help_outline,
          title: 'Help',
          subtitle: 'Wallet & coins FAQs',
          section: _MenuSection.help,
          buildContent: () => _buildHelpInline(),
        ),
      ],
    );
  }

  String _monthName(int m) {
    const names = [
      'January','February','March','April','May','June','July','August','September','October','November','December'
    ];
    return names[(m - 1).clamp(0, 11)];
  }

  void _seedTransactions() {
    final now = DateTime.now();
    _transactions = [
      LedgerTransaction(
        id: 't1',
        userId: 'me',
        type: LedgerTransactionType.adReward,
        amount: 8,
        timestamp: now.subtract(const Duration(minutes: 20)),
        status: LedgerTransactionStatus.completed,
        description: 'Watched video: Kids Learning Fun',
      ),
      LedgerTransaction(
        id: 't2',
        userId: 'me',
        type: LedgerTransactionType.payout,
        amount: -139,
        timestamp: now.subtract(const Duration(hours: 1)),
        status: LedgerTransactionStatus.completed,
        description: 'Redeemed on order #9c2656b4',
      ),
      LedgerTransaction(
        id: 't3',
        userId: 'me',
        type: LedgerTransactionType.adReward,
        amount: 8,
        timestamp: now.subtract(const Duration(hours: 2)),
        status: LedgerTransactionStatus.completed,
        description: 'Watched video: Kids Learning Fun',
      ),
      LedgerTransaction(
        id: 't4',
        userId: 'me',
        type: LedgerTransactionType.payout,
        amount: -139,
        timestamp: now.subtract(const Duration(hours: 3)),
        status: LedgerTransactionStatus.completed,
        description: 'Redeemed on order #9c2656b4',
      ),
      LedgerTransaction(
        id: 't5',
        userId: 'me',
        type: LedgerTransactionType.adReward,
        amount: 20,
        timestamp: now.subtract(const Duration(days: 2, hours: 4)),
        status: LedgerTransactionStatus.failed,
        description: 'Expired bonus coins',
      ),
      LedgerTransaction(
        id: 't6',
        userId: 'me',
        type: LedgerTransactionType.payout,
        amount: -50,
        timestamp: now.subtract(const Duration(days: 5)),
        status: LedgerTransactionStatus.blocked,
        description: 'Expired cashback redemption',
      ),
    ];
    _recalculateTotals();
  }

  void _recalculateTotals() {
    int earnedLifetime = 0;
    int spentLifetime = 0;
    int earnedMonth = 0;
    int spentMonth = 0;
    final now = DateTime.now();
    for (final t in _transactions) {
      if (t.amount > 0) {
        earnedLifetime += t.amount;
        if (t.timestamp.year == now.year && t.timestamp.month == now.month) {
          earnedMonth += t.amount;
        }
      } else if (t.amount < 0) {
        final v = t.amount.abs();
        spentLifetime += v;
        if (t.timestamp.year == now.year && t.timestamp.month == now.month) {
          spentMonth += v;
        }
      }
    }
    setState(() {
      _totalEarnedLifetime = earnedLifetime;
      _totalSpentLifetime = spentLifetime;
      _totalEarnedMonth = earnedMonth;
      _totalSpentMonth = spentMonth;
    });
  }

  Widget _buildTransactionSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _applyFilters(_transactions);
    final display = _historyState == _HistoryState.expanded ? filtered : filtered.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              children: [
                Tooltip(
                  message: 'Filter',
                  child: TextButton(
                    onPressed: _openFilterModal,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      foregroundColor: InstagramTheme.textBlack,
                      backgroundColor: isDark ? const Color(0xFF1E1E1E) : InstagramTheme.surfaceWhite,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Icon(Icons.tune, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _historyState == _HistoryState.hidden ? 0.0 : 0.25,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.linear,
                  child: IconButton(
                    tooltip: 'Toggle view',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _historyState = _historyState == _HistoryState.hidden
                            ? _HistoryState.minimal
                            : _HistoryState.hidden;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_historyState != _HistoryState.hidden)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: InstagramTheme.borderGrey),
            ),
            constraints: BoxConstraints(maxHeight: _historyState == _HistoryState.expanded ? 300 : 180),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _transactionQuickFilter = _TransactionQuickFilter.all;
                            });
                          },
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: _transactionQuickFilter == _TransactionQuickFilter.all
                                  ? InstagramTheme.primaryPink.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              border: Border.all(
                                color: _transactionQuickFilter == _TransactionQuickFilter.all
                                    ? InstagramTheme.primaryPink
                                    : InstagramTheme.borderGrey,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _transactionQuickFilter == _TransactionQuickFilter.all
                                    ? InstagramTheme.primaryPink
                                    : (isDark ? Colors.white : InstagramTheme.textBlack),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _transactionQuickFilter = _TransactionQuickFilter.earned;
                            });
                          },
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: _transactionQuickFilter == _TransactionQuickFilter.earned
                                  ? InstagramTheme.primaryPink.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              border: Border.all(
                                color: _transactionQuickFilter == _TransactionQuickFilter.earned
                                    ? InstagramTheme.primaryPink
                                    : InstagramTheme.borderGrey,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Earned',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _transactionQuickFilter == _TransactionQuickFilter.earned
                                    ? InstagramTheme.primaryPink
                                    : (isDark ? Colors.white : InstagramTheme.textBlack),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _transactionQuickFilter = _TransactionQuickFilter.spent;
                            });
                          },
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: _transactionQuickFilter == _TransactionQuickFilter.spent
                                  ? InstagramTheme.primaryPink.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              border: Border.all(
                                color: _transactionQuickFilter == _TransactionQuickFilter.spent
                                    ? InstagramTheme.primaryPink
                                    : InstagramTheme.borderGrey,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Spent',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _transactionQuickFilter == _TransactionQuickFilter.spent
                                    ? InstagramTheme.primaryPink
                                    : (isDark ? Colors.white : InstagramTheme.textBlack),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _transactionQuickFilter = _TransactionQuickFilter.expired;
                            });
                          },
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: _transactionQuickFilter == _TransactionQuickFilter.expired
                                  ? InstagramTheme.primaryPink.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              border: Border.all(
                                color: _transactionQuickFilter == _TransactionQuickFilter.expired
                                    ? InstagramTheme.primaryPink
                                    : InstagramTheme.borderGrey,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Expired',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _transactionQuickFilter == _TransactionQuickFilter.expired
                                    ? InstagramTheme.primaryPink
                                    : (isDark ? Colors.white : InstagramTheme.textBlack),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _historyState == _HistoryState.expanded
                      ? Scrollbar(
                          interactive: true,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemBuilder: (ctx, i) => _buildTransactionRow(display[i]),
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemCount: display.length,
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (ctx, i) => _buildTransactionRow(display[i]),
                          separatorBuilder: (ctx, i) => const Divider(height: 1),
                          itemCount: display.length,
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionRow(LedgerTransaction t) {
    final isCredit = t.amount >= 0;
    final amountColor = isCredit ? Colors.green : Colors.red;
    final icon = t.type == LedgerTransactionType.adReward
        ? Icons.play_circle_outline
        : Icons.receipt_long;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: InstagramTheme.backgroundGrey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: InstagramTheme.textGrey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.description ?? _labelForType(t.type),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(_formatTimestamp(t.timestamp), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        Text(
          (isCredit ? '+${t.amount}' : '${t.amount}'),
          style: TextStyle(color: amountColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _labelForType(LedgerTransactionType type) {
    switch (type) {
      case LedgerTransactionType.adReward:
        return 'Ad reward';
      case LedgerTransactionType.giftReceived:
        return 'Gift received';
      case LedgerTransactionType.giftSent:
        return 'Gift sent';
      case LedgerTransactionType.payout:
        return 'Redeemed';
      case LedgerTransactionType.refund:
        return 'Refund';
    }
  }

  String _formatTimestamp(DateTime dt) {
    final d = '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$d at $h:$m $ampm';
  }

  List<LedgerTransaction> _applyFilters(List<LedgerTransaction> list) {
    return list.where((t) {
      if (_filterType != null && t.type != _filterType) return false;
      if (_filterStart != null && t.timestamp.isBefore(_filterStart!)) return false;
      if (_filterEnd != null && t.timestamp.isAfter(_filterEnd!)) return false;
      if (_coinsComparator != 'any' && _coinsValue != null) {
        final v = t.amount.abs();
        switch (_coinsComparator) {
          case '=':
            if (v != _coinsValue) return false;
            break;
          case '>=':
            if (v < _coinsValue!) return false;
            break;
          case '<=':
            if (v > _coinsValue!) return false;
            break;
        }
      }
      switch (_transactionQuickFilter) {
        case _TransactionQuickFilter.all:
          break;
        case _TransactionQuickFilter.earned:
          if (t.amount <= 0) return false;
          break;
        case _TransactionQuickFilter.spent:
          if (t.amount >= 0) return false;
          break;
        case _TransactionQuickFilter.expired:
          if (t.status == LedgerTransactionStatus.completed) return false;
          break;
      }
      return true;
    }).toList();
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        DateTime? start = _filterStart;
        DateTime? end = _filterEnd;
        LedgerTransactionType? type = _filterType;
        String comparator = _coinsComparator;
        int? coins = _coinsValue;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(context: ctx, initialDate: start ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (picked != null) {
                            start = DateTime(picked.year, picked.month, picked.day);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(start == null ? 'Start date' : '${_monthName(start.month)} ${start.day}, ${start.year}'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: InstagramTheme.borderGrey),
                          foregroundColor: InstagramTheme.textBlack,
                          backgroundColor: InstagramTheme.surfaceWhite,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(context: ctx, initialDate: end ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (picked != null) {
                            end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(end == null ? 'End date' : '${_monthName(end.month)} ${end.day}, ${end.year}'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: InstagramTheme.borderGrey),
                          foregroundColor: InstagramTheme.textBlack,
                          backgroundColor: InstagramTheme.surfaceWhite,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LedgerTransactionType?>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Received Type'),
                  items: [
        const DropdownMenuItem<LedgerTransactionType?>(value: null, child: Text('Any')),
        DropdownMenuItem<LedgerTransactionType?>(value: LedgerTransactionType.adReward, child: const Text('Earned (Ad Reward)')),
        DropdownMenuItem<LedgerTransactionType?>(value: LedgerTransactionType.payout, child: const Text('Spent (Redeemed)')),
        DropdownMenuItem<LedgerTransactionType?>(value: LedgerTransactionType.giftReceived, child: const Text('Gift Received')),
        DropdownMenuItem<LedgerTransactionType?>(value: LedgerTransactionType.giftSent, child: const Text('Gift Sent')),
        DropdownMenuItem<LedgerTransactionType?>(value: LedgerTransactionType.refund, child: const Text('Refund')),
                  ],
                  onChanged: (v) => type = v,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: comparator,
                      items: const [
                        DropdownMenuItem(value: 'any', child: Text('Any')),
                        DropdownMenuItem(value: '=', child: Text('= coins')),
                        DropdownMenuItem(value: '>=', child: Text('≥ coins')),
                        DropdownMenuItem(value: '<=', child: Text('≤ coins')),
                      ],
                      onChanged: (v) => comparator = v ?? 'any',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'No. of Coins'),
                        onChanged: (v) => coins = int.tryParse(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filterStart = null;
                          _filterEnd = null;
                          _filterType = null;
                          _coinsComparator = 'any';
                          _coinsValue = null;
                        });
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: InstagramTheme.borderGrey),
                        foregroundColor: InstagramTheme.textBlack,
                        backgroundColor: InstagramTheme.surfaceWhite,
                      ),
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterStart = start;
                          _filterEnd = end;
                          _filterType = type;
                          _coinsComparator = comparator;
                          _coinsValue = coins;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: InstagramTheme.primaryPink,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRedeemDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redeem Coins'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available: $_coinBalance coins'),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Coins to redeem'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Redeem')),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help'),
        content: const Text('Manage your wallet balance, view transactions, and redeem coins.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required _MenuSection section,
    required Widget Function() buildContent,
  }) {
    final open = _menuOpen == section;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClayContainer(
        borderRadius: 16,
        color: InstagramTheme.surfaceWhite,
        onTap: () {
          setState(() {
            _menuOpen = open ? _MenuSection.none : section;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: InstagramTheme.primaryPink.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: InstagramTheme.primaryPink, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: InstagramTheme.textBlack,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: InstagramTheme.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.linear,
                    child: const Icon(Icons.chevron_right, color: InstagramTheme.textGrey),
                  ),
                ],
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: open ? buildContent() : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowToEarnDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: InstagramTheme.surfaceWhite,
        title: const Text('How to Earn Coins', 
          style: TextStyle(color: InstagramTheme.textBlack)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(text: '1. Watch Ads: Earn coins by watching advertisements'),
            SizedBox(height: 12),
            _InfoRow(text: '2. Receive Gifts: Get coins from other users'),
            SizedBox(height: 12),
            _InfoRow(text: '3. Complete Tasks: Earn coins by completing various tasks'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it', style: TextStyle(color: InstagramTheme.primaryPink)),
          ),
        ],
      ),
    );
  }

  void _unfocus(BuildContext context) {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _loadAccountDetails() {
    final details = _walletService.getAccountDetails();
    if (details != null) {
      setState(() {
        _existingDetails = details;
        _nameController.text = details.accountHolderName;
        _accountNumberController.text = details.accountNumber;
        _selectedPaymentMethod = details.paymentMethod;
        _bankNameController.text = details.bankName ?? '';
        _ifscController.text = details.ifscCode ?? '';
      });
    }
  }

  Future<void> _saveAccountInline() async {
    setState(() {
      _isSavingDetails = true;
    });
    final details = AccountDetails(
      id: _existingDetails?.id ?? 'acc-${DateTime.now().millisecondsSinceEpoch}',
      accountHolderName: _nameController.text.trim(),
      paymentMethod: _selectedPaymentMethod,
      accountNumber: _accountNumberController.text.trim(),
      bankName: _selectedPaymentMethod == 'Bank' ? _bankNameController.text.trim() : null,
      ifscCode: _selectedPaymentMethod == 'Bank' ? _ifscController.text.trim() : null,
      createdAt: _existingDetails?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final ok = await _walletService.saveAccountDetails(details);
    setState(() {
      _isSavingDetails = false;
      if (ok) {
        _existingDetails = details;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Account details saved' : 'Failed to save'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildAccountDetailsInline() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InstagramTheme.borderGrey),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'UPI', label: Text('UPI')),
              ButtonSegment(value: 'Bank', label: Text('Bank')),
              ButtonSegment(value: 'PayPal', label: Text('PayPal')),
            ],
            selected: {_selectedPaymentMethod},
            onSelectionChanged: (s) => setState(() => _selectedPaymentMethod = s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Account Holder Name',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _accountNumberController,
            decoration: InputDecoration(
              labelText: _selectedPaymentMethod == 'UPI'
                  ? 'UPI ID'
                  : _selectedPaymentMethod == 'Bank'
                      ? 'Account Number'
                      : 'Email / ID',
              prefixIcon: const Icon(Icons.account_balance_wallet),
            ),
          ),
          if (_selectedPaymentMethod == 'Bank') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: 'Bank Name',
                prefixIcon: Icon(Icons.account_balance),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ifscController,
              decoration: const InputDecoration(
                labelText: 'IFSC Code',
                prefixIcon: Icon(Icons.code),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSavingDetails ? null : () {
                    _unfocus(context);
                    _saveAccountInline();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InstagramTheme.primaryPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isSavingDetails
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemInline() {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InstagramTheme.borderGrey),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available: $_coinBalance coins', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Coins to redeem', prefixIcon: Icon(Icons.redeem)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _unfocus(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Redeem flow is stubbed')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InstagramTheme.primaryPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Redeem'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpInline() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InstagramTheme.borderGrey),
      ),
      padding: const EdgeInsets.all(12),
      child: const Text(
        'Manage your wallet balance, view transactions, and redeem coins.',
        style: TextStyle(color: InstagramTheme.textGrey),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String text;
  const _InfoRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 16, color: InstagramTheme.primaryPink),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: InstagramTheme.textGrey)),
        ),
      ],
    );
  }
}
