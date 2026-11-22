import 'dart:convert';

import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api.dart';
import '../services/wallet_service.dart';
import '../services/page_cache_service.dart';
import '../utils/current_user.dart';
import '../models/ledger_model.dart';
import '../widgets/floating_message_overlay.dart';
import 'messaging_screen.dart';

enum _WalletSection { none, transaction, account, help }

enum _TransactionQuickFilter { all, earned, spent }

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final AuthApi _authApi = AuthApi();
  final PageCacheService _pageCache = PageCacheService();
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
  _WalletSection _openSection = _WalletSection.none;
  _TransactionQuickFilter _transactionQuickFilter = _TransactionQuickFilter.all;
  int? _openHelpTopic;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet({bool forceNetwork = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUserId = await _safeUserId();
    final cacheParams = <String, dynamic>{'section': _openSection.name};
    final cached = forceNetwork ? null : await _pageCache.get('wallet', currentUserId, cacheParams);

    if (cached != null) {
      try {
        final decoded = const JsonDecoder().convert(cached) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _meProfile = decoded['meProfile'] is Map
              ? Map<String, dynamic>.from(decoded['meProfile'] as Map)
              : null;
          _walletData = decoded['walletData'] is Map
              ? Map<String, dynamic>.from(decoded['walletData'] as Map)
              : null;
          _coinBalance = _parseMaybeInt(decoded['coinBalance']) ?? 0;
          _totalEarnedLifetime = _parseMaybeInt(decoded['totalEarnedLifetime']) ?? 0;
          _totalSpentLifetime = _parseMaybeInt(decoded['totalSpentLifetime']) ?? 0;
          _totalEarnedMonth = _parseMaybeInt(decoded['totalEarnedMonth']) ?? 0;
          _totalSpentMonth = _parseMaybeInt(decoded['totalSpentMonth']) ?? 0;
          _isLoading = false;
        });
        // Cache doesn't hold transactions; load them so the 30-day chart,
        // transaction count and history are populated.
        _walletService.getTransactions().then((txs) {
          if (!mounted) return;
          setState(() => _transactions = txs);
        }).catchError((_) {});
        return;
      } on Exception catch (_) {
        await _pageCache.invalidate('wallet', currentUserId);
      }
    }

    try {
      final meRaw = await _authApi.me();
      final me = _normalizeProfile(meRaw);
      final data =
          await _walletService.fetchMemberWalletHistoryForCurrentUser();
      final summary = data['summary'] is Map
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : <String, dynamic>{};
      final parsedTransactions = await _walletService.getTransactions();
      final balance = await _walletService.getCoinBalance();
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

      try {
        await _pageCache.set('wallet', currentUserId, cacheParams, const JsonEncoder().convert(<String, dynamic>{
          'meProfile': me,
          'walletData': data,
          'coinBalance': balance,
          'totalEarnedLifetime': earnedFromSummary ?? lifetimeEarned,
          'totalSpentLifetime': spentFromSummary ?? lifetimeSpent,
          'totalEarnedMonth': monthEarned,
          'totalSpentMonth': monthSpent,
        }));
      } on Exception catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<String> _safeUserId() async {
    final id = await CurrentUser.id;
    return id?.trim().isNotEmpty == true ? id!.trim() : 'anon';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAF8);
    final appBarBg =
        isDark ? const Color(0xE60A0A0A) : const Color(0xE6FAFAF8);
    final titleColor = isDark ? Colors.white : const Color(0xFF0A0A0A);
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
           RefreshIndicator(
             onRefresh: () => _loadWallet(forceNetwork: true),
             color: const Color(0xFFF97316),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: appBarBg,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  toolbarHeight: 68,
                  leadingWidth: 68,
                  titleSpacing: 6,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Center(
                      child: _HeaderIconButton(
                        icon: LucideIcons.arrowLeft,
                        onPressed: () => Navigator.of(context).maybePop(),
                        isLoading: false,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      const Icon(LucideIcons.wallet,
                          size: 22, color: Color(0xFFF97316)),
                      const SizedBox(width: 10),
                      Text(
                        'Vault',
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 21,
                            color: titleColor),
                      ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
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
                      style: GoogleFonts.montserrat(color: titleColor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBalanceCard(),
                          const SizedBox(height: 16),
                          if (_errorMessage != null) ...[
                            _buildErrorBanner(),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          _buildRedeemGiftCardsCard(),
                          const SizedBox(height: 12),
                          _buildRedemptionRequestCard(),
                          const SizedBox(height: 12),
                          _AccordionItem(
                            leading: const _CircleIcon(
                              color: Color(0xFF16A34A),
                              icon: Icons.schedule_rounded,
                            ),
                            title: 'Transaction History',
                            badge: _transactions.isEmpty
                                ? null
                                : _transactions.length,
                            isOpen: _openSection == _WalletSection.transaction,
                            onToggle: () => setState(() {
                              _openSection =
                                  _openSection == _WalletSection.transaction
                                      ? _WalletSection.none
                                      : _WalletSection.transaction;
                            }),
                            child: _buildTransactionHistory(),
                          ),
                          const SizedBox(height: 12),
                          _AccordionItem(
                            leading: const Icon(Icons.person_rounded,
                                size: 32, color: Color(0xFF6D4AFF)),
                            title: 'Account Details',
                            isOpen: _openSection == _WalletSection.account,
                            onToggle: () => setState(() {
                              _openSection =
                                  _openSection == _WalletSection.account
                                      ? _WalletSection.none
                                      : _WalletSection.account;
                            }),
                            child: _buildAccountDetails(),
                          ),
                          const SizedBox(height: 12),
                          _AccordionItem(
                            leading: const _CircleIcon(
                              color: Color(0xFF64748B),
                              icon: Icons.question_mark_rounded,
                            ),
                            title: 'Help',
                            isOpen: _openSection == _WalletSection.help,
                            onToggle: () => setState(() {
                              _openSection = _openSection == _WalletSection.help
                                  ? _WalletSection.none
                                  : _WalletSection.help;
                              if (_openSection == _WalletSection.none) {
                                _openHelpTopic = null;
                              }
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
          Positioned.fill(
            child: FloatingMessageOverlay(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MessagingScreen(),
                  ),
                );
              },
            ),
          ),
        ],
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
    final d =
        '${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month).substring(0, 3)} ${dt.year}';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$d · $h:$m $ampm';
  }

  /// bCoins per Rs 1. Uses a backend value when the wallet payload has one,
  /// otherwise the same 50:1 rate the gift-card screen uses.
  int get _coinsPerRupee {
    final data = _walletData;
    if (data != null) {
      final summary = data['summary'] is Map ? data['summary'] as Map : const {};
      for (final key in const [
        'coins_per_rupee',
        'coinsPerRupee',
        'conversion_rate',
        'conversionRate',
        'coin_rate',
        'rate',
      ]) {
        final v = _parseMaybeInt(data[key]) ?? _parseMaybeInt(summary[key]);
        if (v != null && v > 0) return v;
      }
    }
    return 50;
  }

  /// Coins received per day for the last 30 days (oldest first).
  List<int> _last30DaysReceived() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = List<int>.filled(30, 0);
    for (final t in _transactions) {
      if (t.amount <= 0) continue;
      final ts = t.timestamp.toLocal();
      final diff = today.difference(DateTime(ts.year, ts.month, ts.day)).inDays;
      if (diff >= 0 && diff < 30) buckets[29 - diff] += t.amount;
    }
    return buckets;
  }

  Widget _buildBalanceCard() {
    final totalEarned = _isLifeTime ? _totalEarnedLifetime : _totalEarnedMonth;
    final totalSpent = _isLifeTime ? _totalSpentLifetime : _totalSpentMonth;
    final totalTx = _transactions.length;
    final daily = _last30DaysReceived();
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7A1A), Color(0xFFEA580C), Color(0xFFC2410C)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33F97316),
              blurRadius: 28,
              spreadRadius: -6,
              offset: Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          // Soft glassy blob on the right side.
          Positioned(
            top: 36,
            bottom: 36,
            right: -70,
            child: Container(
              width: 290,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(160),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _dot(0.45),
                    const SizedBox(width: 6),
                    _dot(0.45),
                    const SizedBox(width: 12),
                    Text(
                      'Available Balance',
                      style: GoogleFonts.montserrat(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _isLifeTime = !_isLifeTime),
                      child: Text(
                        _isLifeTime
                            ? 'Lifetime'
                            : _monthName(DateTime.now().month),
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _VaultToggle(
                      value: _isLifeTime,
                      onChanged: (v) => setState(() => _isLifeTime = v),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _isLoading && _walletData == null
                          ? Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white70),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Loading…',
                                  style: GoogleFonts.montserrat(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatCoins(_coinBalance),
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontSize: 54,
                                      fontWeight: FontWeight.w800,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      'bCoins',
                                      style: GoogleFonts.montserrat(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Rate",
                            style: GoogleFonts.montserrat(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rs 1 = $_coinsPerRupee bCoins',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Last 30 Days Received',
                  style: GoogleFonts.montserrat(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                _ReceivedBars(values: daily),
                Container(
                  height: 3,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: const Color(0xFFFF8A3D).withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 14),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      _StatPill(
                          label: 'Total Earned',
                          value: '+${_formatCoins(totalEarned)}',
                          color: const Color(0xFF4ADE80)),
                      _statDivider(),
                      _StatPill(
                          label: 'Total Spent',
                          value: '-${_formatCoins(totalSpent)}',
                          color: const Color(0xFFF472B6)),
                      _statDivider(),
                      _StatPill(
                          label: 'Transactions',
                          value: '$totalTx',
                          color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double alpha) => Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD1B0).withValues(alpha: alpha + 0.3),
          shape: BoxShape.circle,
        ),
      );

  Widget _statDivider() => Container(
        width: 1.2,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: Colors.white.withValues(alpha: 0.3),
      );
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
          const Icon(LucideIcons.circleAlert,
              size: 16, color: Color(0xFFFB7185)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'Failed to load vault data',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                  color: const Color(0xFFFB7185), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _loadWallet,
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFFB923C)),
            child: Text('Retry',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
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
    final chipBg =
        isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF7F7FA);
    final chipBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final emptyColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);
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
                  isActive:
                      _transactionQuickFilter == _TransactionQuickFilter.all,
                  onTap: () => setState(() =>
                      _transactionQuickFilter = _TransactionQuickFilter.all),
                ),
                _FilterTab(
                  label: 'Earned',
                  isActive:
                      _transactionQuickFilter == _TransactionQuickFilter.earned,
                  onTap: () => setState(() =>
                      _transactionQuickFilter = _TransactionQuickFilter.earned),
                ),
                _FilterTab(
                  label: 'Spent',
                  isActive:
                      _transactionQuickFilter == _TransactionQuickFilter.spent,
                  onTap: () => setState(() =>
                      _transactionQuickFilter = _TransactionQuickFilter.spent),
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
                    style: GoogleFonts.montserrat(
                        color: emptyColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: math.min(filtered.length, 5) * 68 +
                  (math.min(filtered.length, 5) - 1) * 10,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                primary: false,
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _TransactionTile(
                  tx: filtered[i],
                  meta: _txMeta(filtered[i]),
                  formatDate: _formatDateTime,
                ),
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
      return _TxMeta(
          label: label,
          icon: icon,
          iconColor: iconColor,
          bgColor: bgColor,
          isCredit: isCredit);
    }

    if (rawType == 'AD_LIKE_REWARD') {
      return m(
          label: 'Spotlight Like Reward',
          icon: LucideIcons.heart,
          iconColor: const Color(0xFF34D399),
          bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_LIKE_REWARD_REVERSAL') {
      return m(
          label: 'Like Reversed',
          icon: LucideIcons.heart,
          iconColor: const Color(0xFFFB7185),
          bgColor: const Color(0x1AFB7185));
    }
    if (rawType == 'AD_VIEW_REWARD') {
      return m(
          label: 'Spotlight View Reward',
          icon: LucideIcons.eye,
          iconColor: const Color(0xFF34D399),
          bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_VIEW_DEDUCTION') {
      return m(
          label: 'Spotlight View Spent',
          icon: LucideIcons.eye,
          iconColor: const Color(0xFFFB7185),
          bgColor: const Color(0x1AFB7185));
    }
    if (rawType == 'AD_COMMENT_REWARD' || rawType == 'COMMENT') {
      return m(
          label: 'Comment Reward',
          icon: LucideIcons.messageCircle,
          iconColor: const Color(0xFF34D399),
          bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_REPLY_REWARD') {
      return m(
          label: 'Reply Reward',
          icon: LucideIcons.messageCircle,
          iconColor: const Color(0xFF34D399),
          bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_SAVE_REWARD' || rawType == 'SAVE') {
      return m(
          label: 'Save Reward',
          icon: LucideIcons.bookmark,
          iconColor: const Color(0xFF34D399),
          bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'AD_LIKE_DEDUCTION') {
      return m(
          label: 'Like Budget Spent',
          icon: LucideIcons.heart,
          iconColor: const Color(0xFFFB7185),
          bgColor: const Color(0x1AFB7185));
    }
    if (rawType == 'AD_BUDGET_DEDUCTION') {
      return m(
          label: 'Spotlight Budget Deducted',
          icon: LucideIcons.trendingDown,
          iconColor: const Color(0xFFFB7185),
          bgColor: const Color(0x1AFB7185));
    }
    if (rawType == 'AD_LIKE_BUDGET_REFUND') {
      return m(
          label: 'Like Budget Refund',
          icon: LucideIcons.trendingUp,
          iconColor: const Color(0xFF38BDF8),
          bgColor: const Color(0x1A38BDF8));
    }
    if (rawType == 'VENDOR_REGISTRATION_CREDIT') {
      return m(
          label: 'Registration Bonus',
          icon: LucideIcons.sparkles,
          iconColor: const Color(0xFFFBBF24),
          bgColor: const Color(0x1AFBBF24));
    }
    if (rawType == 'VENDOR_RECHARGE') {
      return m(
          label: 'Vault Recharge',
          icon: LucideIcons.trendingUp,
          iconColor: const Color(0xFF34D399),
          bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'ADMIN_ADJUSTMENT') {
      return m(
          label: 'Admin Adjustment',
          icon: LucideIcons.slidersHorizontal,
          iconColor: const Color(0xFFA78BFA),
          bgColor: const Color(0x1AA78BFA));
    }
    if (rawType == 'REEL_VIEW_REWARD' ||
        rawType == 'VENDOR_PROFILE_VIEW_REWARD') {
      return m(
          label: 'Spotlight View Reward',
          icon: LucideIcons.eye,
          iconColor: const Color(0xFF34D399),
          bgColor: const Color(0x1A34D399));
    }
    if (rawType == 'LIKE') {
      return m(
          label: 'Spotlight Like Reward',
          icon: LucideIcons.heart,
          iconColor: const Color(0xFF34D399),
          bgColor: const Color(0x1A34D399));
    }
    return m(
        label: rawType.isEmpty ? 'bCoins' : rawType,
        icon: LucideIcons.coins,
        iconColor: const Color(0xFF9CA3AF),
        bgColor: const Color(0x1A9CA3AF));
  }

  Widget _buildAccountDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletUser = _walletData?['user'] is Map
        ? Map<String, dynamic>.from(_walletData!['user'] as Map)
        : <String, dynamic>{};
    final user = <String, dynamic>{...walletUser, ...?_meProfile};
    final wallet = _walletData?['wallet'] is Map
        ? Map<String, dynamic>.from(_walletData!['wallet'] as Map)
        : <String, dynamic>{};

    final role = (user['role'] ?? '').toString().trim();
    final name = (user['full_name'] ?? user['username'] ?? '—').toString();
    final username = (user['username'] ?? '—').toString();
    final avatarUrl = (user['avatar_url'] ?? '').toString().trim();
    final email = (user['email'] ?? '').toString();
    final phone = (user['phone'] ?? '').toString();
    final currency = (wallet['currency'] ?? 'bCoins').toString();
    final companyDetails = user['company_details'] is Map
        ? Map<String, dynamic>.from(user['company_details'] as Map)
        : <String, dynamic>{};
    final surface =
        isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final avatarBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final titleColor = isDark ? Colors.white : const Color(0xFF0A0A0A);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.45);
    final iconMuted = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

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
                            errorBuilder: (_, __, ___) => Icon(LucideIcons.user,
                                size: 18, color: iconMuted),
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
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: titleColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: subColor),
                      ),
                    ],
                  ),
                ),
                if (role.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0x1AF97316),
                      border: Border.all(color: const Color(0x33F97316)),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: GoogleFonts.montserrat(
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
          _AccountRow(
              label: 'Email',
              value: email.isEmpty ? '—' : email,
              icon: LucideIcons.mail),
          const SizedBox(height: 10),
          _AccountRow(
              label: 'Phone',
              value: phone.isEmpty ? '—' : phone,
              icon: LucideIcons.phone),
          const SizedBox(height: 10),
          _AccountRow(
            label: 'Balance',
            value: '${_coinBalance.toString()} bCoins',
            icon: LucideIcons.coins,
            valueColor: const Color(0xFFFB923C),
          ),
          const SizedBox(height: 10),
          _AccountRow(
              label: 'Currency',
              value: currency,
              icon: LucideIcons.badgeDollarSign),
          if (role.toLowerCase() == 'vendor' && companyDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.building2,
                          size: 16,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.45)),
                      const SizedBox(width: 8),
                      Text(
                        'Company Details',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.7),
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
                      _CompanyChip(
                          label: 'Company',
                          value: companyDetails['company_name']),
                      _CompanyChip(
                          label: 'Legal Name',
                          value: companyDetails['legal_business_name']),
                      _CompanyChip(
                          label: 'Industry', value: companyDetails['industry']),
                      _CompanyChip(
                          label: 'Website', value: companyDetails['website']),
                      _CompanyChip(
                          label: 'Business Email',
                          value: companyDetails['business_email']),
                      _CompanyChip(
                          label: 'Business Phone',
                          value: companyDetails['business_phone']),
                      _CompanyChip(
                          label: 'City', value: companyDetails['city']),
                      _CompanyChip(
                          label: 'Country', value: companyDetails['country']),
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
    final topics = [
      _HelpTopic(
        title: 'Earning BCoins',
        icon: LucideIcons.sparkles,
        sections: [
          _HelpSection(
            question: 'How do I earn BCoins?',
            answer:
                'You can earn Coins through eligible in-app activity and special rewards.',
            bullets: const [
              'Watching eligible videos or content.',
              'Participating in campaigns, challenges, or events.',
              'Completing tasks and activities within the app.',
              'Receiving promotional or bonus rewards during special events.',
            ],
          ),
        ],
      ),
      _HelpTopic(
        title: 'Redeeming BCoins',
        icon: LucideIcons.gift,
        sections: [
          _HelpSection(
            question: 'How do I redeem bCoins?',
            answer:
                'Open Vault, tap Redeem Gift Cards, choose a card, pick the required value, and confirm the request.',
            bullets: const [
              'Go to Vault.',
              'Tap Redeem Gift Cards.',
              'Choose your preferred gift card.',
              'Select the required card value.',
              'Ensure you have enough Coins.',
              'Confirm the redemption request.',
              'Track the status under Redemption Request.',
            ],
          ),
          _HelpSection(
            question: 'Is there a minimum number of bCoins required?',
            answer:
                'Yes. Each gift card has its own minimum Coin requirement, which is shown before you redeem.',
          ),
          _HelpSection(
            question: 'Can I cancel a redemption request?',
            answer:
                'Usually not after submission and processing. If you need help, contact Support.',
          ),
          _HelpSection(
            question: 'Why can’t I redeem my bCoins?',
            answer: 'Common reasons include:',
            bullets: const [
              'Insufficient bCoins balance.',
              'Temporary service maintenance.',
              'Reward currently unavailable.',
              'Account verification is incomplete.',
              'Daily or monthly redemption limit has been reached.',
            ],
          ),
        ],
      ),
      _HelpTopic(
        title: 'Balance & Processing',
        icon: LucideIcons.wallet,
        sections: [
          _HelpSection(
            question: 'Why is my bCoin balance different?',
            answer:
                'Your balance can change after successful redemptions, new earnings, expired promotional Coins, or while a transaction is processing.',
            bullets: const [
              'Coins were successfully redeemed.',
              'New Coins were added after eligible activity.',
              'Promotional or bonus Coins expired.',
              'A transaction is still being processed.',
            ],
            footer:
                'Check Transaction History for the full breakdown of earned and spent Coins.',
          ),
          _HelpSection(
            question: 'How long does redemption take?',
            answer:
                'Most redemption requests are processed within 2 to 72 hours, depending on the reward provider.',
          ),
          _HelpSection(
            question: 'Do bCoins expire?',
            answer:
                'Some promotional or bonus Coins may expire. Check the campaign or offer details for the validity period.',
          ),
        ],
      ),
      _HelpTopic(
        title: 'Notifications & Status',
        icon: LucideIcons.bell,
        sections: [
          _HelpSection(
            question: 'How will I be notified after voucher redemption?',
            answer:
                'You may receive an in-app notification, an email, or an SMS depending on your notification settings and service availability.',
            bullets: const [
              'In-App Notification',
              'Email',
              'SMS (Text Message)',
            ],
            footer:
                'You can also view the redemption status and voucher details anytime under Wallet & Coins → Redemption Request.',
          ),
          _HelpSection(
            question: 'Where can I check my redemption status?',
            answer: 'Open Redemption Request to view:',
            bullets: const [
              'Pending requests',
              'Processing requests',
              'Successful redemptions',
              'Failed or cancelled requests',
            ],
          ),
        ],
      ),
      _HelpTopic(
        title: 'Support & Tips',
        icon: LucideIcons.info,
        sections: [
          _HelpSection(
            question: 'How can I contact Support?',
            answer:
                'Go to Profile → Settings → Help & Support → Raise a Ticket.',
            bullets: const [
              'Go to Profile.',
              'Open Settings.',
              'Navigate to Help & Support.',
              'Select Raise a Ticket or Contact Support.',
              'Submit your issue and the support team will review it.',
            ],
          ),
          _HelpSection(
            question: 'Tips',
            answer: 'A few things that help keep your rewards smooth:',
            bullets: const [
              'Complete your profile to unlock more earning opportunities.',
              'Check the app regularly for bonus campaigns and limited-time offers.',
              'Review your Transaction History to track earned and redeemed Coins.',
              'Ensure your account details are up to date before redeeming rewards.',
              'Do not share your account credentials with anyone.',
              'Follow the app’s Terms & Conditions to avoid forfeiture of Coins.',
            ],
          ),
        ],
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          for (var i = 0; i < topics.length; i++) ...[
            _AccordionItem(
              title: topics[i].title,
              isOpen: _openHelpTopic == i,
              onToggle: () => setState(() {
                _openHelpTopic = _openHelpTopic == i ? null : i;
              }),
              child: _buildHelpTopicBody(topics[i]),
            ),
            if (i != topics.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildHelpTopicBody(_HelpTopic topic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final questionColor = isDark ? Colors.white : const Color(0xFF0A0A0A);
    final answerColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.68);
    final bulletColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF97316).withValues(alpha: 0.10),
                ),
                child:
                    Icon(topic.icon, size: 16, color: const Color(0xFFF97316)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap a topic below to expand the answer',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: answerColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < topic.sections.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sectionBorder),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFFDFDFE),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.sections[i].question,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: questionColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic.sections[i].answer,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: answerColor,
                    ),
                  ),
                  if (topic.sections[i].bullets.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final bullet in topic.sections[i].bullets) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: bulletColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bullet,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                                color: answerColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  if (topic.sections[i].footer != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      topic.sections[i].footer!,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: answerColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (i != topic.sections.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildRedeemGiftCardsCard() {
    return _VaultNavTile(
      leading: const Icon(Icons.card_giftcard_rounded,
          size: 32, color: Color(0xFFEF4444)),
      title: 'Redeem Gift Cards',
      onTap: () => Navigator.of(context).pushNamed('/wallet/redeem-gift-cards'),
    );
  }

  Widget _buildRedemptionRequestCard() {
    return _VaultNavTile(
      leading: Transform.rotate(
        angle: -0.3,
        child: const Icon(Icons.confirmation_number_rounded,
            size: 32, color: Color(0xFF2563EB)),
      ),
      title: 'Redemption Request',
      onTap: () =>
          Navigator.of(context).pushNamed('/wallet/redemption-requests'),
    );
  }
}

/// Shared look for the vault menu rows (nav tiles + accordion headers).
class _VaultTileStyle {
  final Color bg;
  final Color border;
  final Color title;
  final Color chevron;

  const _VaultTileStyle(this.bg, this.border, this.title, this.chevron);

  factory _VaultTileStyle.of(BuildContext context, {bool open = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? _VaultTileStyle(
            open ? const Color(0xFF141414) : const Color(0xFF0F0F0F),
            Colors.white.withValues(alpha: open ? 0.10 : 0.07),
            Colors.white,
            Colors.white.withValues(alpha: 0.5),
          )
        : _VaultTileStyle(
            open ? Colors.white : const Color(0xFFF4F6FB),
            const Color(0xFFE3E7EF),
            const Color(0xFF0A0A0A),
            const Color(0xFF4B5563),
          );
  }
}

TextStyle _vaultTileTitle(Color color) => GoogleFonts.montserrat(
    fontWeight: FontWeight.w700, fontSize: 16.5, color: color);

class _VaultNavTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final VoidCallback onTap;

  const _VaultNavTile(
      {required this.leading, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = _VaultTileStyle.of(context);
    return Material(
      color: s.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: s.border, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              SizedBox(width: 34, child: Center(child: leading)),
              const SizedBox(width: 18),
              Expanded(child: Text(title, style: _vaultTileTitle(s.title))),
              Icon(LucideIcons.chevronRight, color: s.chevron, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _CircleIcon({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: 19, color: Colors.white),
    );
  }
}

/// Pill toggle styled like the mockup: translucent track, white knob.
class _VaultToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _VaultToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: value
              ? const Color(0xFFFFB27A).withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 30 white bars showing coins received per day.
class _ReceivedBars extends StatelessWidget {
  final List<int> values;

  const _ReceivedBars({required this.values});

  @override
  Widget build(BuildContext context) {
    const maxH = 64.0;
    const minH = 10.0;
    final peak = values.fold<int>(0, math.max);
    return SizedBox(
      height: maxH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.6),
                child: Container(
                  height: peak == 0 ? minH : minH + (v / peak) * (maxH - minH),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: v > 0 ? 0.95 : 0.45),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3), bottom: Radius.circular(1)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _HeaderIconButton(
      {required this.icon, this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFEFEFEF);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1F1F1F);
    final progressColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.55);
    return SizedBox(
      width: 50,
      height: 50,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
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
                : Icon(icon, size: 22, color: iconColor),
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
  final Widget? leading;

  const _AccordionItem({
    this.leading,
    required this.title,
    required this.isOpen,
    required this.onToggle,
    required this.child,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _VaultTileStyle.of(context, open: isOpen);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: s.border, width: 1.2),
        color: s.bg,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  if (leading != null) ...[
                    SizedBox(width: 34, child: Center(child: leading)),
                    const SizedBox(width: 18),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: _vaultTileTitle(s.title),
                          ),
                        ),
                  if (badge != null && badge! > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFFFFE0CC),
                      ),
                      child: Text(
                        badge.toString(),
                        style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: const Color(0xFFEA580C)),
                      ),
                    ),
                  ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(LucideIcons.chevronDown,
                        size: 20, color: s.chevron),
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

  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.montserrat(
                    fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterTab(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.45);
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
            boxShadow: isActive
                ? const [
                    BoxShadow(
                        color: Color(0x4DF97316),
                        blurRadius: 18,
                        offset: Offset(0, 10))
                  ]
                : const [],
          ),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
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

  const _TransactionTile(
      {required this.tx, required this.meta, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
    final tileBg =
        isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF7F7FA);
    final titleColor = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.85);
    final dateColor = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : Colors.black.withValues(alpha: 0.45);
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.25);
    final descColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.45);
    final rawType = (tx.metadata?['type'] ?? '').toString().toUpperCase();
    final label = _normalizedLabel(
      rawType,
      (tx.metadata?['label'] ?? meta.label).toString(),
    );
    final description = _normalizedDescription(
      rawType,
      (tx.metadata?['description'] ?? '').toString(),
    );
    final adTitle = tx.metadata?['ad'] is Map
        ? (tx.metadata?['ad']['title'] ?? '').toString()
        : '';
    final status = (tx.metadata?['status'] ?? '').toString().toUpperCase();
    final isCredit = meta.isCredit;
    final amount = tx.amount.abs();

    final amountColor =
        isCredit ? const Color(0xFF34D399) : const Color(0xFFFB7185);
    final statusColor =
        status == 'SUCCESS' ? const Color(0xFF34D399) : const Color(0xFFFB7185);
    final statusBg =
        status == 'SUCCESS' ? const Color(0x1A34D399) : const Color(0x1AFB7185);

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
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      fontSize: 13),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    Text(formatDate(tx.timestamp),
                        style: GoogleFonts.montserrat(
                            fontSize: 11, color: dateColor)),
                    if (adTitle.isNotEmpty) ...[
                      Text('·',
                          style: GoogleFonts.montserrat(
                              fontSize: 11, color: dotColor)),
                      Text(
                        adTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xB3FB923C)),
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
                    style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: descColor,
                        fontWeight: FontWeight.w600),
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
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                    fontSize: 13),
              ),
              const SizedBox(height: 6),
              if (status.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: statusBg),
                  child: Text(status,
                      style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: statusColor)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _normalizedLabel(String rawType, String fallback) {
    switch (rawType) {
      case 'AD_LIKE_REWARD':
        return 'Spotlight Like Reward';
      case 'AD_LIKE_REWARD_REVERSAL':
        return 'Like Reversed';
      case 'AD_VIEW_REWARD':
        return 'Spotlight View Reward';
      case 'AD_VIEW_DEDUCTION':
        return 'Spotlight View Spent';
      case 'AD_COMMENT_REWARD':
      case 'COMMENT':
        return 'Comment Reward';
      case 'AD_REPLY_REWARD':
        return 'Reply Reward';
      case 'AD_SAVE_REWARD':
      case 'SAVE':
        return 'Save Reward';
      case 'AD_LIKE_DEDUCTION':
        return 'Like Budget Spent';
      case 'AD_BUDGET_DEDUCTION':
        return 'Spotlight Budget Deducted';
      case 'AD_LIKE_BUDGET_REFUND':
        return 'Like Budget Refund';
      case 'REEL_VIEW_REWARD':
      case 'VENDOR_PROFILE_VIEW_REWARD':
        return 'Spotlight View Reward';
      case 'LIKE':
        return 'Spotlight Like Reward';
      default:
        return fallback;
    }
  }

  String _normalizedDescription(String rawType, String fallback) {
    final text = fallback.trim();
    if (text.isEmpty) return text;

    switch (rawType) {
      case 'AD_LIKE_REWARD':
      case 'LIKE':
        return text
            .replaceAll(RegExp(r'\b[Aa]d\b'), 'Spotlight')
            .replaceAll(RegExp(r'\b[Aa]ds\b'), 'Spotlights');
      case 'AD_VIEW_REWARD':
      case 'REEL_VIEW_REWARD':
      case 'VENDOR_PROFILE_VIEW_REWARD':
        return text
            .replaceAll(RegExp(r'\b[Aa]d\b'), 'Spotlight')
            .replaceAll(RegExp(r'\b[Aa]ds\b'), 'Spotlights');
      default:
        return text;
    }
  }
}

class _TxSkeleton extends StatelessWidget {
  const _TxSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final blockStrong = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final blockWeak = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
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
                      Container(
                          height: 10,
                          width: double.infinity,
                          color: blockStrong),
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

  const _AccountRow(
      {required this.label,
      required this.value,
      required this.icon,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
    final bg =
        isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.45);
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);
    final valueCol = valueColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.85));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        color: bg,
      ),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.montserrat(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          const Spacer(),
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                  color: valueCol, fontWeight: FontWeight.w800, fontSize: 13),
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
    final border = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : Colors.black.withValues(alpha: 0.35);
    final valueColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.70);
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
            style: GoogleFonts.montserrat(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: labelColor),
          ),
          const SizedBox(height: 2),
          Text(
            v.isEmpty ? '—' : v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
                fontSize: 12, fontWeight: FontWeight.w800, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _HelpTopic {
  final String title;
  final IconData icon;
  final List<_HelpSection> sections;

  const _HelpTopic({
    required this.title,
    required this.icon,
    required this.sections,
  });
}

class _HelpSection {
  final String question;
  final String answer;
  final List<String> bullets;
  final String? footer;

  const _HelpSection({
    required this.question,
    required this.answer,
    this.bullets = const <String>[],
    this.footer,
  });
}
