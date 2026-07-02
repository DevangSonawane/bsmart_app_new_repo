import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_exceptions.dart';
import '../api/faq_api.dart';
import '../theme/design_tokens.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final FaqApi _faqApi = FaqApi();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _categoryFilter = 'all';
  List<Map<String, dynamic>> _faqs = const [];

  static const List<_FilterOption> _categoryOptions = [
    _FilterOption(label: 'All Topics', value: 'all'),
    _FilterOption(label: 'General', value: 'general'),
    _FilterOption(label: 'Payment', value: 'payment'),
    _FilterOption(label: 'Vendor', value: 'vendor'),
    _FilterOption(label: 'Ads', value: 'ads'),
    _FilterOption(label: 'Other', value: 'other'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadFaqs();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _normalize(String? value) => value?.trim().toLowerCase() ?? '';

  String _faqQuestion(Map<String, dynamic> faq) {
    return (faq['question'] ?? '').toString().trim();
  }

  String _faqAnswer(Map<String, dynamic> faq) {
    return (faq['answer'] ?? '').toString().trim();
  }

  String _faqCategory(Map<String, dynamic> faq) {
    return _normalize(faq['category']);
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'general':
        return 'General';
      case 'payment':
        return 'Payment';
      case 'vendor':
        return 'Vendor';
      case 'ads':
        return 'Ads';
      case 'other':
        return 'Other';
      default:
        return 'All Topics';
    }
  }

  List<Map<String, dynamic>> get _visibleFaqs {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _faqs;

    return _faqs.where((faq) {
      final question = _faqQuestion(faq).toLowerCase();
      final answer = _faqAnswer(faq).toLowerCase();
      final category = _categoryLabel(_faqCategory(faq)).toLowerCase();
      return question.contains(query) ||
          answer.contains(query) ||
          category.contains(query);
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> _sortedFaqs(List<Map<String, dynamic>> faqs) {
    final items = [...faqs];
    items.sort((a, b) {
      final orderA = (a['order'] as num?)?.toInt() ?? 0;
      final orderB = (b['order'] as num?)?.toInt() ?? 0;
      if (orderA != orderB) return orderA.compareTo(orderB);

      final createdA = DateTime.tryParse((a['createdAt'] ?? '').toString());
      final createdB = DateTime.tryParse((b['createdAt'] ?? '').toString());
      if (createdA != null && createdB != null) {
        return createdA.compareTo(createdB);
      }
      return _faqQuestion(a).compareTo(_faqQuestion(b));
    });
    return items;
  }

  Future<void> _loadFaqs() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final category = _categoryFilter == 'all' ? null : _categoryFilter;
      final faqs = await _faqApi.getFaqs(category: category);
      if (!mounted) return;
      setState(() {
        _faqs = _sortedFaqs(faqs);
      });
    } on NotFoundException catch (e) {
      if (!mounted) return;
      setState(() {
        _faqs = const [];
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _setCategoryFilter(String value) {
    if (_categoryFilter == value) return;
    setState(() => _categoryFilter = value);
    _loadFaqs();
  }

  Future<void> _retry() => _loadFaqs();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final visibleFaqs = _visibleFaqs;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('FAQs'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: RefreshIndicator(
          onRefresh: _retry,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorState(
                      message: _error!,
                      onRetry: _retry,
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
                      children: [
                        _searchBar(theme, isDark),
                        const SizedBox(height: 14),
                        _sectionHeader('Browse by topic'),
                        const SizedBox(height: 10),
                        _chipStrip(
                          options: _categoryOptions,
                          selectedValue: _categoryFilter,
                          onSelected: _setCategoryFilter,
                        ),
                        const SizedBox(height: 18),
                        if (visibleFaqs.isEmpty)
                          _EmptyFaqState(
                            searchQuery: _searchController.text.trim(),
                            categoryLabel: _categoryLabel(_categoryFilter),
                          )
                        else
                          ...visibleFaqs.map((faq) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FaqCard(
                                key: ValueKey(
                                  (faq['_id'] ?? faq['id']).toString().trim(),
                                ),
                                faq: faq,
                                categoryLabel:
                                    _categoryLabel(_faqCategory(faq)),
                              ),
                            );
                          }),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _searchBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: 18,
            color: theme.iconTheme.color?.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search FAQs',
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_searchController.text.trim().isNotEmpty)
            InkWell(
              onTap: _searchController.clear,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(LucideIcons.x, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: DesignTokens.instaPink,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _chipStrip({
    required List<_FilterOption> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            ChoiceChip(
              selected: selectedValue == options[i].value,
              label: Text(options[i].label),
              onSelected: (_) => onSelected(options[i].value),
            ),
            if (i != options.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  final Map<String, dynamic> faq;
  final String categoryLabel;

  const _FaqCard({
    super.key,
    required this.faq,
    required this.categoryLabel,
  });

  String get _question => (faq['question'] ?? '').toString().trim();
  String get _answer => (faq['answer'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: DesignTokens.instaPink,
          collapsedIconColor: theme.iconTheme.color?.withValues(alpha: 0.72),
          title: Text(
            _question.isEmpty ? 'Untitled FAQ' : _question,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: categoryLabel, icon: LucideIcons.tag),
              ],
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _answer.isEmpty ? 'No answer available.' : _answer,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetaChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: DesignTokens.instaPink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DesignTokens.instaPink),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DesignTokens.instaPink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFaqState extends StatelessWidget {
  final String searchQuery;
  final String categoryLabel;

  const _EmptyFaqState({
    required this.searchQuery,
    required this.categoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasSearch = searchQuery.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_outlined,
            size: 36,
            color: DesignTokens.instaPink,
          ),
          const SizedBox(height: 12),
          Text(
            hasSearch ? 'No FAQs match your search' : 'No FAQs found',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try a different keyword, or clear the search and browse the chips above.'
                : 'Adjust the topic chips to reveal matching FAQs.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _MiniInfoChip(label: categoryLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final String label;

  const _MiniInfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DesignTokens.instaPink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: DesignTokens.instaPink,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 56),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: DesignTokens.instaPink,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load FAQs',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterOption {
  final String label;
  final String value;

  const _FilterOption({
    required this.label,
    required this.value,
  });
}
