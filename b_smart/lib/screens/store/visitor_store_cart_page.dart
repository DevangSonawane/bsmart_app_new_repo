import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../services/supabase_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_shared_widgets.dart';

class VisitorStoreCartPage extends StatefulWidget {
  final String? ownerUserId;

  const VisitorStoreCartPage({super.key, this.ownerUserId});

  @override
  State<VisitorStoreCartPage> createState() => _VisitorStoreCartPageState();
}

class _VisitorStoreCartPageState extends State<VisitorStoreCartPage> {
  late Future<_CartOwner?> _ownerFuture;

  @override
  void initState() {
    super.initState();
    _ownerFuture = _loadOwner();
  }

  @override
  void didUpdateWidget(covariant VisitorStoreCartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerUserId != widget.ownerUserId) {
      _ownerFuture = _loadOwner();
    }
  }

  Future<_CartOwner?> _loadOwner() async {
    final ownerId = widget.ownerUserId?.trim();
    if (ownerId == null || ownerId.isEmpty) return null;

    final user = await SupabaseService().getUserById(ownerId);
    if (user == null) return null;

    final name = _firstString(user, const [
      'full_name',
      'fullName',
      'displayName',
      'name',
      'username',
    ]);
    final avatarUrl = UrlHelper.absoluteUrl(
      _firstString(user, const [
            'avatar_url',
            'avatarUrl',
            'profile_picture',
            'profilePicture',
            'profile_image',
            'profileImage',
            'photoUrl',
            'avatar',
          ]) ??
          '',
    );

    Map<String, String>? avatarHeaders;
    if (avatarUrl.isNotEmpty && UrlHelper.shouldAttachAuthHeader(avatarUrl)) {
      final token = await ApiClient().getToken();
      if (token != null && token.isNotEmpty) {
        avatarHeaders = {'Authorization': 'Bearer $token'};
      }
    }

    return _CartOwner(
      displayName: name ?? 'Store owner',
      avatarUrl: avatarUrl,
      avatarHeaders: avatarHeaders,
    );
  }

  static String? _firstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        const _CartHeader(),
        const _SelectionCard(),
        FutureBuilder<_CartOwner?>(
          future: _ownerFuture,
          builder: (context, snapshot) {
            return _CartStoreCard(
              owner: snapshot.data,
              isLoading: snapshot.connectionState != ConnectionState.done,
            );
          },
        ),
        const _CartItemCard(
          imageAsset: 'assets/bSmart_Store/mockimages/vegetables.jpg',
          title: 'Eco Cleaning Kit',
          price: r'$24.99',
        ),
        const SizedBox(height: 10),
        const _CartItemCard(
          imageAsset: 'assets/bSmart_Store/mockimages/clothes.jpg',
          title: 'Handmade Notebook',
          price: r'$15.00',
        ),
        const _DeliveryCard(),
        const _BCoinsCard(),
        const _CartTotalsCard(),
        const _CheckoutButton(),
      ],
    );
  }
}

class _CartOwner {
  final String displayName;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _CartOwner({
    required this.displayName,
    required this.avatarUrl,
    required this.avatarHeaders,
  });
}

class _CartHeader extends StatelessWidget {
  const _CartHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        0,
      ),
      child: const Column(
        children: [
          SizedBox(height: 30, child: Center(child: StoreBsmartWordmark())),
          SizedBox(height: 12),
          Text(
            'My Cart',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Row(
          children: [
            const _CheckedBox(size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '2 selected items',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF078D92),
                padding: EdgeInsets.zero,
                minimumSize: const Size(66, 32),
              ),
              child: const Text(
                'Select all',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartStoreCard extends StatelessWidget {
  final _CartOwner? owner;
  final bool isLoading;

  const _CartStoreCard({
    required this.owner,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final ownerName = owner?.displayName.trim().isNotEmpty == true
        ? owner!.displayName.trim()
        : (isLoading ? 'Loading store...' : 'Store owner');
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Row(
          children: [
            _OwnerAvatar(
              name: ownerName,
              avatarUrl: owner?.avatarUrl ?? '',
              avatarHeaders: owner?.avatarHeaders,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$ownerName's Personal Store",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Personal Store',
                    style: TextStyle(
                      color: Color(0xFF684AC8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _OwnerAvatar({
    required this.name,
    required this.avatarUrl,
    required this.avatarHeaders,
  });

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFEAD8CC),
        alignment: Alignment.center,
        child: avatarUrl.trim().isEmpty
            ? _Initial(name: name, fontSize: 15)
            : SafeNetworkImage(
                url: avatarUrl,
                headers: avatarHeaders,
                width: size,
                height: size,
                fit: BoxFit.cover,
                debugLabel: 'visitor-cart-owner-avatar',
                errorWidget: _Initial(name: name, fontSize: 15),
              ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String price;

  const _CartItemCard({
    required this.imageAsset,
    required this.title,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Container(
        height: 126,
        padding: const EdgeInsets.all(10),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    imageAsset,
                    width: 116,
                    height: 106,
                    fit: BoxFit.cover,
                    cacheWidth: 360,
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  child: _CheckedBox(size: 22),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF060D35),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.heart,
                        color: Color(0xFF060D35),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: const TextStyle(
                      color: Color(0xFF078D92),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const _QuantityStepper(),
                      const Spacer(),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(LucideIcons.trash2, size: 19),
                        color: const Color(0xFF060D35),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5DEE4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(LucideIcons.minus, color: Color(0xFF078D92), size: 15),
          Text(
            '1',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Icon(LucideIcons.plus, color: Color(0xFF078D92), size: 16),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: storeSoftCardDecoration(radius: 12),
        child: const Row(
          children: [
            _SoftIconBubble(icon: LucideIcons.truck),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery',
                    style: TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Arrives in 2-3 days',
                    style: TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BCoinsCard extends StatelessWidget {
  const _BCoinsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: storeSoftCardDecoration(radius: 12),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFF078D92),
              child: Text(
                'b',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'You will earn ',
                  children: [
                    TextSpan(
                      text: '400 bCoins',
                      style: TextStyle(color: Color(0xFF078D92)),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, color: Color(0xFF060D35), size: 18),
          ],
        ),
      ),
    );
  }
}

class _CartTotalsCard extends StatelessWidget {
  const _CartTotalsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: storeSoftCardDecoration(radius: 12),
        child: const Column(
          children: [
            _TotalRow(label: 'Subtotal', value: r'$39.99'),
            SizedBox(height: 10),
            _TotalRow(
              label: 'Delivery',
              value: 'Free',
              valueColor: Color(0xFF078D92),
            ),
            Divider(height: 20, color: Color(0xFFE1E5EA)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  r'$39.99',
                  style: TextStyle(
                    color: Color(0xFF078D92),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _TotalRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF29304D),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF060D35),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: SizedBox(
        height: 46,
        child: FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF078D92),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Proceed to Checkout',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _CheckedBox extends StatelessWidget {
  final double size;

  const _CheckedBox({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF078D92),
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(LucideIcons.check, color: Colors.white, size: size * 0.6),
    );
  }
}

class _SoftIconBubble extends StatelessWidget {
  final IconData icon;

  const _SoftIconBubble({required this.icon});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFFE5F5F3),
      child: Icon(icon, color: const Color(0xFF060D35), size: 19),
    );
  }
}

class _Initial extends StatelessWidget {
  final String name;
  final double fontSize;

  const _Initial({required this.name, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? 'S' : trimmed.characters.first.toUpperCase();
    return Text(
      initial,
      style: TextStyle(
        color: const Color(0xFF060D35),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
