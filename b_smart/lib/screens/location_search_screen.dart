import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/location_api.dart';
import '../models/location_place.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _api = LocationApi();
  final _rand = Random();

  Timer? _debounce;
  String _sessionToken = '';
  int _requestSerial = 0;
  bool _loading = false;
  List<LocationPlace> _places = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller
      ..removeListener(_handleTextChange)
      ..dispose();
    super.dispose();
  }

  String _newSessionToken() {
    List<int> bytes = List<int>.generate(16, (_) => _rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final parts = [
      bytes.take(4).map(hex).join(),
      bytes.skip(4).take(2).map(hex).join(),
      bytes.skip(6).take(2).map(hex).join(),
      bytes.skip(8).take(2).map(hex).join(),
      bytes.skip(10).take(6).map(hex).join(),
    ];
    return parts.join('-');
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _sessionToken = _newSessionToken();
    }
  }

  void _handleTextChange() {
    final value = _controller.text.trim();
    if (mounted) setState(() {});
    if (value.isEmpty) {
      _debounce?.cancel();
      if (_places.isNotEmpty || _error != null || _loading) {
        setState(() {
          _places = const [];
          _error = null;
          _loading = false;
        });
      }
      _sessionToken = _newSessionToken();
      return;
    }

    _debounce?.cancel();
    if (value.length < 2) {
      if (_places.isNotEmpty || _error != null || _loading) {
        setState(() {
          _places = const [];
          _error = null;
          _loading = false;
        });
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(value);
    });
  }

  Future<void> _search(String value) async {
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final places = await _api.searchPlaces(
        value,
        sessionToken: _sessionToken,
      );
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _places = places;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _places = const [];
        _error = 'Unable to load locations right now.';
      });
    } finally {
      if (mounted && serial == _requestSerial) {
        setState(() => _loading = false);
      }
    }
  }

  void _clear() {
    _controller.clear();
    _sessionToken = _newSessionToken();
    setState(() {
      _places = const [];
      _error = null;
      _loading = false;
    });
    _focusNode.requestFocus();
  }

  void _select(LocationPlace place) {
    _sessionToken = _newSessionToken();
    Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final fg = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: bg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: fg,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border.withValues(alpha: 0.35)),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search city, area, building...',
              hintStyle: TextStyle(color: muted, fontSize: 14),
              prefixIcon: Icon(LucideIcons.search, color: muted, size: 18),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(LucideIcons.x, color: muted, size: 18),
                      onPressed: _clear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
            ),
            style: TextStyle(color: fg, fontSize: 15),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _places.isEmpty
                ? _buildEmptyState(muted)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _places.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: border.withValues(alpha: 0.45),
                    ),
                    itemBuilder: (context, index) {
                      final place = _places[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(
                          place.displayText,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: place.address.isNotEmpty
                            ? Text(
                                place.address,
                                style: TextStyle(color: muted),
                              )
                            : null,
                        onTap: () => _select(place),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState(Color muted) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 15),
          ),
        ),
      );
    }

    if (_controller.text.trim().length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Type at least 2 characters to search for a location.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 15),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No places found.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 15),
        ),
      ),
    );
  }
}
