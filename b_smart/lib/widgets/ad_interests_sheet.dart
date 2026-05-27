import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/users_api.dart';
import '../theme/design_tokens.dart';

class AdInterestsSheet extends StatefulWidget {
  final String userId;
  final List<String> initialInterests;
  final bool editable;
  final ValueChanged<List<String>>? onSaved;

  const AdInterestsSheet({
    super.key,
    required this.userId,
    this.initialInterests = const <String>[],
    this.editable = true,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    List<String> initialInterests = const <String>[],
    bool editable = true,
    ValueChanged<List<String>>? onSaved,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.86,
          child: AdInterestsSheet(
            userId: userId,
            initialInterests: initialInterests,
            editable: editable,
            onSaved: onSaved,
          ),
        ),
      ),
    );
  }

  @override
  State<AdInterestsSheet> createState() => _AdInterestsSheetState();
}

class _AdInterestsSheetState extends State<AdInterestsSheet> {
  final UsersApi _api = UsersApi();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<String> _available = const <String>[];
  final Set<String> _selected = <String>{};
  late final Set<String> _initial;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialInterests
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    _selected
      ..clear()
      ..addAll(_initial);
    unawaited(_load());
  }

  bool get _dirty {
    if (_selected.length != _initial.length) return true;
    for (final s in _selected) {
      if (!_initial.contains(s)) return true;
    }
    return false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getAdInterests(widget.userId);
      final ad = res['ad_interests'];
      final avail = res['available_categories'];

      final nextSelected = <String>{};
      if (ad is List) {
        for (final v in ad) {
          final s = (v ?? '').toString().trim();
          if (s.isNotEmpty) nextSelected.add(s);
        }
      }
      // If server returned nothing, fall back to initial.
      if (nextSelected.isEmpty) nextSelected.addAll(_selected);

      final nextAvail = <String>[];
      if (avail is List) {
        for (final v in avail) {
          final s = (v ?? '').toString().trim();
          if (s.isNotEmpty) nextAvail.add(s);
        }
      }
      if (nextAvail.isEmpty) {
        // Minimal fallback so UI still works.
        nextAvail.addAll(nextSelected);
      }

      if (!mounted) return;
      setState(() {
        _available = nextAvail;
        _selected
          ..clear()
          ..addAll(nextSelected);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load interests';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final selected = _selected.toList()..sort();
      final res = await _api.updateAdInterests(
        widget.userId,
        interests: selected,
      );

      final ad = res['ad_interests'];
      final next = <String>[];
      if (ad is List) {
        for (final v in ad) {
          final s = (v ?? '').toString().trim();
          if (s.isNotEmpty) next.add(s);
        }
      } else {
        next.addAll(selected);
      }

      if (!mounted) return;
      widget.onSaved?.call(next);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save interests';
        _saving = false;
      });
    }
  }

  String _emojiForCategory(String category) {
    final key = category.trim().toLowerCase();
    switch (key) {
      case 'all':
        return '🏷️';
      case 'accessories':
        return '👜';
      case 'action figures':
        return '🤖';
      case 'art supplies':
        return '🎨';
      case 'baby products':
        return '🍼';
      case 'beauty & personal care':
        return '💄';
      case 'books':
        return '📚';
      case 'clothing & apparel':
        return '👕';
      case 'electronics':
        return '💻';
      case 'food & beverages':
        return '🍕';
      case 'footwear':
        return '👟';
      case 'gaming':
        return '🎮';
      case 'health & wellness':
        return '💪';
      case 'home & kitchen':
        return '🏠';
      case 'jewellery':
        return '💎';
      case 'mobile & tablets':
        return '📱';
      case 'pet supplies':
        return '🐾';
      case 'sports & fitness':
        return '⚽';
      case 'toys':
        return '🧸';
      case 'travel':
        return '✈️';
      default:
        return '🏷️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isReadOnly = !widget.editable;
    final disabled = isReadOnly || !_dirty || _saving || _loading;
    final selectedCount = _selected.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.editable ? 'Your Interests' : 'Interests',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
        ),
        if (_loading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: DesignTokens.instaPink),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  isReadOnly
                      ? '$selectedCount selected'
                      : '$selectedCount selected · tap to toggle',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _available.map((c) {
                    final selected = _selected.contains(c);
                    final emoji = _emojiForCategory(c);
                    return FilterChip(
                      selected: selected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji),
                          const SizedBox(width: 8),
                          Text(
                            c,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : colors.onSurface,
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                      showCheckmark: false,
                      selectedColor: DesignTokens.instaPink,
                      backgroundColor: theme.brightness == Brightness.dark
                          ? const Color(0xFF121214)
                          : const Color(0xFFF3F4F6),
                      side: BorderSide(
                        color: selected
                            ? Colors.transparent
                            : colors.onSurface.withValues(alpha: 0.10),
                      ),
                      onSelected: isReadOnly
                          ? null
                          : (v) {
                              setState(() {
                                if (v) {
                                  _selected.add(c);
                                } else {
                                  _selected.remove(c);
                                }
                              });
                            },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: colors.onSurface.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      isReadOnly ? 'Close' : 'Cancel',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              if (!isReadOnly) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: disabled ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.instaPink,
                        disabledBackgroundColor:
                            DesignTokens.instaPink.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Interests',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
