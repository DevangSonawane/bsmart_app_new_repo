import 'package:flutter/material.dart';
import '../api/api.dart';

/// Lightweight gate to mirror React's role-based redirects.
///
/// React parity:
/// - `/ads` redirects vendors → `/vendor-ads`
/// - `/vendor-ads` redirects non-vendors → `/ads`
/// - Vendor-only pages redirect non-vendors → `/ads`
class RoleRedirectGate extends StatefulWidget {
  final Widget child;
  final bool requireVendor;
  final String redirectTo;

  const RoleRedirectGate({
    super.key,
    required this.child,
    required this.requireVendor,
    required this.redirectTo,
  });

  @override
  State<RoleRedirectGate> createState() => _RoleRedirectGateState();
}

class _RoleRedirectGateState extends State<RoleRedirectGate> {
  late final Future<bool> _isVendorFuture;
  bool _didRedirect = false;

  @override
  void initState() {
    super.initState();
    _isVendorFuture = _resolveIsVendor();
  }

  Map<String, dynamic> _normalizeUser(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    if (map['user'] is Map) return Map<String, dynamic>.from(map['user'] as Map);
    if (map['data'] is Map) {
      final data = Map<String, dynamic>.from(map['data'] as Map);
      if (data['user'] is Map) return Map<String, dynamic>.from(data['user'] as Map);
      return data;
    }
    return map;
  }

  Future<bool> _resolveIsVendor() async {
    final token = await ApiClient().getToken();
    if (token == null || token.trim().isEmpty) return false;
    try {
      final meRaw = await AuthApi().me();
      final me = _normalizeUser(meRaw);
      final role = me['role']?.toString().toLowerCase().trim() ?? '';
      return role == 'vendor';
    } catch (_) {
      return false;
    }
  }

  void _redirect() {
    if (_didRedirect) return;
    _didRedirect = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(widget.redirectTo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isVendorFuture,
      builder: (context, snap) {
        final isVendor = snap.data ?? false;
        final ok = widget.requireVendor ? isVendor : !isVendor;

        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!ok) {
          _redirect();
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return widget.child;
      },
    );
  }
}

