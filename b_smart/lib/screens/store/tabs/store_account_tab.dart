import 'package:flutter/material.dart';

import '../../../api/users_api.dart';
import '../../../services/auth/auth_service.dart';

class StoreAccountTab extends StatefulWidget {
  const StoreAccountTab({super.key});

  @override
  State<StoreAccountTab> createState() => _StoreAccountTabState();
}

class _StoreAccountTabState extends State<StoreAccountTab> {
  String _accountName = 'Your Account';

  @override
  void initState() {
    super.initState();
    _loadAccountName();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAccountHeader(),
        _buildAccountQuickActions(),
        _buildRecentlyViewedStores(),
      ],
    );
  }

  Future<void> _loadAccountName() async {
    String? resolvedName;
    try {
      resolvedName = _accountNameFromMap(await UsersApi().getAccountSettings());
    } catch (_) {}

    if (resolvedName == null) {
      final user = await AuthService().fetchCurrentUser();
      if (user != null) {
        resolvedName = _firstMeaningfulString([
          user.fullName,
          user.username,
        ]);
      }
    }

    if (!mounted || resolvedName == null) return;
    setState(() => _accountName = resolvedName!);
  }

  String? _accountNameFromMap(Map<String, dynamic> source) {
    return _firstMeaningfulString([
      source['full_name'],
      source['fullName'],
      source['name'],
      source['displayName'],
      source['username'],
      source['handle'],
    ]);
  }

  String? _firstMeaningfulString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'user') {
        return text;
      }
    }
    return null;
  }

  Widget _buildAccountHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        14,
        MediaQuery.of(context).padding.top + 10,
        14,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _accountName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Publish your products on this app\nand reach more Bsmart shoppers.',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PublishButton(onTap: _openPublishProduct),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountQuickActions() {
    const actions = [
      (Icons.inventory_2_outlined, 'Orders'),
      (Icons.favorite_border_rounded, 'Wishlist'),
      (Icons.card_giftcard_rounded, 'Coupons'),
      (Icons.headset_mic_outlined, 'Help Center'),
    ];
    return Transform.translate(
      offset: const Offset(0, -6),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 4.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, index) {
            final action = actions[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFD8D8D8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.$1, color: const Color(0xFF2A62DC), size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      action.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecentlyViewedStores() {
    return _accountSectionShell(
      topGap: 3,
      bottomGap: 18,
      child: const Text(
        'Recently Viewed Stores',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _accountSectionShell({
    required Widget child,
    double topGap = 0,
    double bottomGap = 0,
  }) {
    return Container(
      color: const Color(0xFFF2F3F6),
      padding: EdgeInsets.only(top: topGap, bottom: bottomGap),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: child,
      ),
    );
  }

  void _openPublishProduct() {
    Navigator.of(context).pushNamed('/store/publish/add-product');
  }
}

class _PublishButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PublishButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            'Publish',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
