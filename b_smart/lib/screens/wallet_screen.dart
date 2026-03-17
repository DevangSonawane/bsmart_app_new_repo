import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api.dart';
import '../services/wallet_service.dart';
import '../models/ledger_model.dart';

enum _WalletSection { none, transaction, account, help }
enum _TransactionQuickFilter { all, earned, spent }

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with TickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final AuthApi _authApi = AuthApi();
  int _coinBalance = 0;
  bool _isLifeTime = true;
  int _totalEarnedLifetime = 0;
  int _totalSpentLifetime = 0;
  int _totalEarnedMonth = 0;
  int _totalSpentMonth = 0;
  Map<String, dynamic>? _walletData;
  Map<String, dynamic>? _meProfile;
  List<LedgerTransaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  _WalletSection _openSection = _WalletSection.transaction;
  _TransactionQuickFilter _transactionQuickFilter = _TransactionQuickFilter.all;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final meRaw = await _authApi.me();
      final me = _normalizeProfile(meRaw);
      final data = await _walletService.fetchMemberWalletHistoryForCurrentUser();
      final wallet = data['wallet'] is Map ? Map<String, dynamic>.from(data['wallet'] as Map) : <String, dynamic>{};
      final summary = data['summary'] is Map ? Map<String, dynamic>.from(data['summary'] as Map) : <String, dynamic>{};
      final parsedTransactions = _mapApiTransactions(data);
      final balanceRaw = wallet['balance'];
      int balance = 0;
      if (balanceRaw is int) {
        balance = balanceRaw;
      } else if (balanceRaw is num) {
        balance = balanceRaw.toInt();
      } else if (balanceRaw is String) {
        balance = int.tryParse(balanceRaw) ?? 0;
      }
      final earnedFromSummary = _parseMaybeInt(summary['total_earned']);
      final spentFromSummary = _parseMaybeInt(summary['total_deducted']);

      int lifetimeEarned = 0;
      int lifetimeSpent = 0;
      int monthEarned = 0;
      int monthSpent = 0;
      final now = DateTime.now();
      for (final t in parsedTransactions) {
        if (t.amount > 0) {
          lifetimeEarned += t.amount;
          if (t.timestamp.year == now.year && t.timestamp.month == now.month) {
            monthEarned += t.amount;
          }
        } else if (t.amount < 0) {
          final abs = t.amount.abs();
          lifetimeSpent += abs;
          if (t.timestamp.year == now.year && t.timestamp.month == now.month) {
            monthSpent += abs;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _meProfile = me;
        _walletData = data;
        _transactions = parsedTransactions;
        _coinBalance = balance;
        _totalEarnedLifetime = earnedFromSummary ?? lifetimeEarned;
        _totalSpentLifetime = spentFromSummary ?? lifetimeSpent;
        _totalEarnedMonth = monthEarned;
        _totalSpentMonth = monthSpent;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
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

  int? _parseMaybeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  LedgerTransactionStatus _mapStatus(String rawStatus) {
    final s = rawStatus.toUpperCase();
    if (s == 'SUCCESS' || s == 'COMPLETED') return LedgerTransactionStatus.completed;
    if (s == 'FAILED') return LedgerTransactionStatus.failed;
    if (s == 'BLOCKED') return LedgerTransactionStatus.blocked;
    return LedgerTransactionStatus.pending;
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

  List<LedgerTransaction> _mapApiTransactions(Map<String, dynamic> data) {
    final txRaw = data['transactions'];
    if (txRaw is! List) return <LedgerTransaction>[];

    final user = data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : <String, dynamic>{};
    final userId = (user['_id'] ?? user['id'] ?? '').toString();

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
          ? DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now()
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final appBarBg = isDark ? const Color(0xE60A0A0A) : const Color(0xE6FFFFFF);
    final titleColor = isDark ? Colors.white : const Color(0xFF0A0A0A);
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: RefreshIndicator(
        onRefresh: _loadWallet,
        color: const Color(0xFFF97316),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: appBarBg,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _HeaderIconButton(
                  icon: LucideIcons.arrowLeft,
                  onPressed: () => Navigator.of(context).maybePop(),
                  isLoading: false,
                ),
              ),
              title: Row(
                children: [
                  const Icon(LucideIcons.wallet, size: 18, color: Color(0xFFFB923C)),
                  const SizedBox(width: 8),
                  Text(
                    'Wallet & Coins',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 16, color: titleColor),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _HeaderIconButton(
                    icon: LucideIcons.refreshCw,
                    onPressed: _loadWallet,
                    isLoading: _isLoading,
                  ),
                ),
              ],
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverToBoxAdapter(
                child: DefaultTextStyle(
                  style: GoogleFonts.dmSans(color: titleColor),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 12),
                      if (_errorMessage != null) _buildErrorBanner(),
                      const SizedBox(height: 12),
                      _AccordionItem(
                        title: 'Transaction History',
                        badge: _transactions.isEmpty ? null : _transactions.length,
                        isOpen: _openSection == _WalletSection.transaction,
                        onToggle: () => setState(() {
                          _openSection = _openSection == _WalletSection.transaction ? _WalletSection.none : _WalletSection.transaction;
                        }),
                        child: _buildTransactionHistory(),
                      ),
                      const SizedBox(height: 12),
                      _AccordionItem(
                        title: 'Account Details',
                        isOpen: _openSection == _WalletSection.account,
                        onToggle: () => setState(() {
                          _openSection = _openSection == _WalletSection.account ? _WalletSection.none : _WalletSection.account;
                        }),
                        child: _buildAccountDetails(),
                      ),
                      const SizedBox(height: 12),
                      _AccordionItem(
                        title: 'Help',
                        isOpen: _openSection == _WalletSection.help,
                        onToggle: () => setState(() {
                          _openSection = _openSection == _WalletSection.help ? _WalletSection.none : _WalletSection.help;
                        }),
                        child: _buildHelp(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[(m - 1).clamp(0, 11)];
  }

  String _formatCoins(int n) {
    final abs = n.abs();
    if (abs >= 1000000) return '${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '${(abs / 1000).toStringAsFixed(1)}K';
    return abs.toString();
  }

  String _formatDateTime(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month).substring(0, 3)} ${dt.year}';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$d · $h:$m $ampm';
  }

  Widget _buildBalanceCard() {
    final totalEarned = _isLifeTime ? _totalEarnedLifetime : _totalEarnedMonth;
    final totalSpent = _isLifeTime ? _totalSpentLifetime : _totalSpentMonth;
    final totalTx = _transactions.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFC2410C)],
          stops: [0.0, 0.4, 1.0],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x73F97316), blurRadius: 40, offset: Offset(0, 18)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -32,
            right: -32,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -24,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Available Balance',
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _isLifeTime ? 'Lifetime' : _monthName(DateTime.now().month),
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 36,
                    height: 20,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: Switch(
                        value: _isLifeTime,
                        onChanged: (v) => setState(() => _isLifeTime = v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: Colors.white.withValues(alpha: 0.3),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.black.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_isLoading && _walletData == null)
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Loading…',
                      style: GoogleFonts.dmSans(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCoins(_coinBalance),
                      style: GoogleFonts.dmMono(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'coins',
                        style: GoogleFonts.dmSans(color: Colors.white.withValues(alpha: 0.85), fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _StatPill(label: 'Total Earned', value: '+${_formatCoins(totalEarned)}', color: const Color(0xFF34D399)),
                  const SizedBox(width: 14),
                  Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(width: 14),
                  _StatPill(label: 'Total Spent', value: '-${_formatCoins(totalSpent)}', color: const Color(0xFFFB7185)),
                  const SizedBox(width: 14),
                  Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(width: 14),
                  _StatPill(label: 'Transactions', value: '$totalTx', color: Colors.white),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33FB7185)),
        color: const Color(0x1AFB7185),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert, size: 16, color: Color(0xFFFB7185)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'Failed to load wallet data',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(color: const Color(0xFFFB7185), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _loadWallet,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFB923C)),
            child: Text('Retry', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  List<LedgerTransaction> _filteredTransactions() {
    switch (_transactionQuickFilter) {
      case _TransactionQuickFilter.all:
        return _transactions;
      case _TransactionQuickFilter.earned:
        return _transactions.where((t) => t.amount > 0).toList();
      case _TransactionQuickFilter.spent:
        return _transactions.where((t) => t.amount < 0).toList();
    }
  }

  Widget _buildTransactionHistory() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredTransactions();
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF7F7FA);
    final chipBorder = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final emptyColor = isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: chipBorder),
            ),
            child: Row(
              children: [
                _FilterTab(
                  label: 'All',
                  isActive: _transactionQuickFilter == _TransactionQuickFilter.all,
                  onTap: () => setState(() => _transactionQuickFilter = _TransactionQuickFilter.all),
                ),
                _FilterTab(
                  label: 'Earned',
                  isActive: _transactionQuickFilter == _TransactionQuickFilter.earned,
                  onTap: () => setState(() => _transactionQuickFilter = _TransactionQuickFilter.earned),
                ),
                _FilterTab(
                  label: 'Spent',
                  isActive: _transactionQuickFilter == _TransactionQuickFilter.spent,
                  onTap: () => setState(() => _transactionQuickFilter = _TransactionQuickFilter.spent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading && _walletData == null)
            const _TxSkeleton()
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(LucideIcons.coins, size: 28, color: emptyColor),
                  const SizedBox(height: 8),
                  Text(
                    'No transactions yet',
                    style: GoogleFonts.dmSans(color: emptyColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              padding: EdgeInsets.zero,
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TransactionTile(
                tx: filtered[i],
                meta: _txMeta(filtered[i]),
                formatDate: _formatDateTime,
              ),
            ),
        ],
      ),
    );
  }

  _TxMeta _txMeta(LedgerTransaction t) {
    final rawType = (t.metadata?['type'] ?? '').toString().toUpperCase();
    final direction = (t.metadata?['direction'] ?? '').toString().toLowerCase();
    final isCredit = direction == 'credit' || t.amount > 0;

    _TxMeta m({
      required String label,
      required IconData icon,
      required Color iconColor,
      required Color bgColor,
    }) {
      return _TxMeta(label: label, icon: icon, iconColor: iconColor, bgColor: bgColor, isCredit: isCredit);
    }

    if (rawType == 'AD_LIKE_REWARD') {
      return m(label: 'Ad Like Reward', icon: LucideIcons.heart, iconColor: const Color(0xFF34D399), bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_LIKE_REWARD_REVERSAL') {
      return m(label: 'Like Reversed', icon: LucideIcons.heart, iconColor: const Color(0xFFFB7185), bgColor: const Color(0x1AFB7185));
    }
    if (rawType == 'AD_VIEW_REWARD') {
      return m(label: 'Ad View Reward', icon: LucideIcons.eye, iconColor: const Color(0xFF34D399), bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_VIEW_DEDUCTION') {
      return m(label: 'Ad View Spent', icon: LucideIcons.eye, iconColor: const Color(0xFFFB7185), bgColor: const Color(0x1AFB7185));
    }
    if (rawType == 'AD_COMMENT_REWARD' || rawType == 'COMMENT') {
      return m(label: 'Comment Reward', icon: LucideIcons.messageCircle, iconColor: const Color(0xFF34D399), bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_REPLY_REWARD') {
      return m(label: 'Reply Reward', icon: LucideIcons.messageCircle, iconColor: const Color(0xFF34D399), bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_SAVE_REWARD' || rawType == 'SAVE') {
      return m(label: 'Save Reward', icon: LucideIcons.bookmark, iconColor: const Color(0xFF34D399), bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_LIKE_DEDUCTION') {
      return m(label: 'Like Budget Spent', icon: LucideIcons.heart, iconColor: const Color(0xFFFB7185), bgColor: const Color(0x1AFB7185));
    }
    if (rawType == 'AD_BUDGET_DEDUCTION') {
      return m(label: 'Ad Budget Deducted', icon: LucideIcons.trendingDown, iconColor: const Color(0xFFFB7185), bgColor: const Color(0x1AFB7185));
    }
    if (rawType == 'AD_LIKE_BUDGET_REFUND') {
      return m(label: 'Like Budget Refund', icon: LucideIcons.trendingUp, iconColor: const Color(0xFF38BDF8), bgColor: const Color(0x1A38BDF8));
    }
    if (rawType == 'VENDOR_REGISTRATION_CREDIT') {
      return m(label: 'Registration Bonus', icon: LucideIcons.sparkles, iconColor: const Color(0xFFFBBF24), bgColor: const Color(0x1AFBBF24));
    }
    if (rawType == 'VENDOR_RECHARGE') {
      return m(label: 'Wallet Recharge', icon: LucideIcons.trendingUp, iconColor: const Color(0xFF34D399), bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'ADMIN_ADJUSTMENT') {
      return m(label: 'Admin Adjustment', icon: LucideIcons.slidersHorizontal, iconColor: const Color(0xFFA78BFA), bgColor: const Color(0x1AA78BFA));
    }
    if (rawType == 'REEL_VIEW_REWARD' || rawType == 'VENDOR_PROFILE_VIEW_REWARD') {
      return m(label: 'View Reward', icon: LucideIcons.eye, iconColor: const Color(0xFF34D399), bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'LIKE') {
      return m(label: 'Like Reward', icon: LucideIcons.heart, iconColor: const Color(0xFF34D399), bgColor: const Color(0x1A34D399));
    }
    return m(label: rawType.isEmpty ? 'Coins' : rawType, icon: LucideIcons.coins, iconColor: const Color(0xFF9CA3AF), bgColor: const Color(0x1A9CA3AF));
  }

  Widget _buildAccountDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletUser = _walletData?['user'] is Map ? Map<String, dynamic>.from(_walletData!['user'] as Map) : <String, dynamic>{};
    final user = <String, dynamic>{...walletUser, ...?_meProfile};
    final wallet = _walletData?['wallet'] is Map ? Map<String, dynamic>.from(_walletData!['wallet'] as Map) : <String, dynamic>{};

    final role = (user['role'] ?? '').toString().trim();
    final name = (user['full_name'] ?? user['username'] ?? '—').toString();
    final username = (user['username'] ?? '—').toString();
    final avatarUrl = (user['avatar_url'] ?? '').toString().trim();
    final email = (user['email'] ?? '').toString();
    final phone = (user['phone'] ?? '').toString();
    final currency = (wallet['currency'] ?? 'Coins').toString();
    final companyDetails = user['company_details'] is Map ? Map<String, dynamic>.from(user['company_details'] as Map) : <String, dynamic>{};
    final surface = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final border = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final avatarBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final titleColor = isDark ? Colors.white : const Color(0xFF0A0A0A);
    final subColor = isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.45);
    final iconMuted = isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: avatarUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            avatarUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(LucideIcons.user, size: 18, color: iconMuted),
                          ),
                        )
                      : Icon(LucideIcons.user, size: 18, color: iconMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 14, color: titleColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                ),
                if (role.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0x1AF97316),
                      border: Border.all(color: const Color(0x33F97316)),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFFFB923C),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AccountRow(label: 'Email', value: email.isEmpty ? '—' : email, icon: LucideIcons.mail),
          const SizedBox(height: 10),
          _AccountRow(label: 'Phone', value: phone.isEmpty ? '—' : phone, icon: LucideIcons.phone),
          const SizedBox(height: 10),
          _AccountRow(
            label: 'Balance',
            value: '${_coinBalance.toString()} Coins',
            icon: LucideIcons.coins,
            valueColor: const Color(0xFFFB923C),
          ),
          const SizedBox(height: 10),
          _AccountRow(label: 'Currency', value: currency, icon: LucideIcons.badgeDollarSign),
          if (role.toLowerCase() == 'vendor' && companyDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.building2, size: 16, color: isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.45)),
                      const SizedBox(width: 8),
                      Text(
                        'Company Details',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.7,
                    children: [
                      _CompanyChip(label: 'Company', value: companyDetails['company_name']),
                      _CompanyChip(label: 'Legal Name', value: companyDetails['legal_business_name']),
                      _CompanyChip(label: 'Industry', value: companyDetails['industry']),
                      _CompanyChip(label: 'Website', value: companyDetails['website']),
                      _CompanyChip(label: 'Business Email', value: companyDetails['business_email']),
                      _CompanyChip(label: 'Business Phone', value: companyDetails['business_phone']),
                      _CompanyChip(label: 'City', value: companyDetails['city']),
                      _CompanyChip(label: 'Country', value: companyDetails['country']),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHelp() {
    final items = ['How do coins work?', 'Why is my balance changed?', 'Contact support'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          for (final item in items) ...[
            _HelpRow(label: item, onTap: () {}),
            if (item != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _HeaderIconButton({required this.icon, this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.75);
    final progressColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55);
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  )
                : Icon(icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _AccordionItem extends StatelessWidget {
  final String title;
  final bool isOpen;
  final VoidCallback onToggle;
  final Widget child;
  final int? badge;

  const _AccordionItem({
    required this.title,
    required this.isOpen,
    required this.onToggle,
    required this.child,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: isOpen ? 0.10 : 0.06)
        : Colors.black.withValues(alpha: isOpen ? 0.10 : 0.06);
    final bg = isDark ? (isOpen ? const Color(0xFF141414) : const Color(0xFF0F0F0F)) : (isOpen ? Colors.white : const Color(0xFFF7F7FA));
    final titleColor = isDark ? Colors.white : const Color(0xFF0A0A0A);
    final chevronColor = isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.35);
    final divider = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        color: bg,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: titleColor, fontSize: 14),
                  ),
                  if (badge != null && badge! > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0x33F97316),
                        border: Border.all(color: const Color(0x55F97316)),
                      ),
                      child: Text(
                        badge.toString(),
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w900, fontSize: 10, color: const Color(0xFFFB923C)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(LucideIcons.chevronDown, size: 18, color: chevronColor),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isOpen
                  ? Column(
                      children: [
                        Container(height: 1, color: divider),
                        child,
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterTab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.45);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive ? const Color(0xFFF97316) : Colors.transparent,
            boxShadow: isActive ? const [BoxShadow(color: Color(0x4DF97316), blurRadius: 18, offset: Offset(0, 10))] : const [],
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: isActive ? Colors.white : inactive,
            ),
          ),
        ),
      ),
    );
  }
}

class _TxMeta {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final bool isCredit;

  const _TxMeta({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.isCredit,
  });
}

class _TransactionTile extends StatelessWidget {
  final LedgerTransaction tx;
  final _TxMeta meta;
  final String Function(DateTime dt) formatDate;

  const _TransactionTile({required this.tx, required this.meta, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06);
    final tileBg = isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF7F7FA);
    final titleColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.85);
    final dateColor = isDark ? Colors.white.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.45);
    final dotColor = isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.25);
    final descColor = isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.45);
    final label = (tx.metadata?['label'] ?? meta.label).toString();
    final description = (tx.metadata?['description'] ?? '').toString();
    final adTitle = tx.metadata?['ad'] is Map ? (tx.metadata?['ad']['title'] ?? '').toString() : '';
    final status = (tx.metadata?['status'] ?? '').toString().toUpperCase();
    final isCredit = meta.isCredit;
    final amount = tx.amount.abs();

    final amountColor = isCredit ? const Color(0xFF34D399) : const Color(0xFFFB7185);
    final statusColor = status == 'SUCCESS' ? const Color(0xFF34D399) : const Color(0xFFFB7185);
    final statusBg = status == 'SUCCESS' ? const Color(0x1A34D399) : const Color(0x1AFB7185);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        color: tileBg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: meta.bgColor,
            ),
            child: Icon(meta.icon, size: 16, color: meta.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: titleColor, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    Text(formatDate(tx.timestamp), style: GoogleFonts.dmMono(fontSize: 11, color: dateColor)),
                    if (adTitle.isNotEmpty) ...[
                      Text('·', style: GoogleFonts.dmSans(fontSize: 11, color: dotColor)),
                      Text(
                        adTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xB3FB923C)),
                      ),
                    ],
                  ],
                ),
                if (description.isNotEmpty && description != label) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(fontSize: 11, color: descColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}$amount',
                style: GoogleFonts.dmMono(fontWeight: FontWeight.w900, color: amountColor, fontSize: 13),
              ),
              const SizedBox(height: 6),
              if (status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: statusBg),
                  child: Text(status, style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 10, color: statusColor)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxSkeleton extends StatelessWidget {
  const _TxSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final border = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final blockStrong = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final blockWeak = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06);
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: bg,
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: blockStrong,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 10, width: double.infinity, color: blockStrong),
                      const SizedBox(height: 8),
                      Container(height: 8, width: 140, color: blockWeak),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(height: 12, width: 44, color: blockStrong),
              ],
            ),
          ),
          if (i != 2) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _AccountRow({required this.label, required this.value, required this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06);
    final bg = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.45);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35);
    final valueCol = valueColor ?? (isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.85));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        color: bg,
      ),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.dmSans(color: labelColor, fontWeight: FontWeight.w700, fontSize: 12)),
          const Spacer(),
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(color: valueCol, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyChip extends StatelessWidget {
  final String label;
  final dynamic value;

  const _CompanyChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.35);
    final valueColor = isDark ? Colors.white.withValues(alpha: 0.70) : Colors.black.withValues(alpha: 0.70);
    final v = (value ?? '').toString().trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: labelColor),
          ),
          const SizedBox(height: 2),
          Text(
            v.isEmpty ? '—' : v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HelpRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final border = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.60);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.25);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(color: labelColor, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}
