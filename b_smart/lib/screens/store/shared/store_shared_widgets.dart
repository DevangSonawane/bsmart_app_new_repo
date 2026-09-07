import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../store_theme.dart';

class StoreBsmartWordmark extends StatelessWidget {
  const StoreBsmartWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
          children: [
            TextSpan(text: 'B', style: TextStyle(color: Color(0xFF078D92))),
            TextSpan(text: 'SMART', style: TextStyle(color: Color(0xFF071238))),
          ],
        ),
      ),
    );
  }
}

enum StoreDashboardTone { teal, purple }

extension StoreDashboardToneColor on StoreDashboardTone {
  Color get color => switch (this) {
        StoreDashboardTone.teal => const Color(0xFF078D92),
        StoreDashboardTone.purple => const Color(0xFF684AC8),
      };

  Color get background => switch (this) {
        StoreDashboardTone.teal => const Color(0xFFE9F6F5),
        StoreDashboardTone.purple => const Color(0xFFF1ECFA),
      };
}

BoxDecoration storeSoftCardDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFE9ECEF)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.055),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class StoreSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const StoreSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StoreEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const StoreEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3E7ED)),
        ),
        child: Column(
          children: [
            Icon(icon, color: StorePalette.blue, size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreListingPreviewList extends StatelessWidget {
  const StoreListingPreviewList({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          StoreListingRow(
            icon: LucideIcons.packageOpen,
            title: 'Product listings',
            subtitle: 'Inventory, pricing, photos, and delivery settings.',
          ),
          SizedBox(height: 10),
          StoreListingRow(
            icon: LucideIcons.briefcaseBusiness,
            title: 'Service listings',
            subtitle: 'Availability, location, pricing, and booking details.',
          ),
        ],
      ),
    );
  }
}

class StoreListingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const StoreListingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3E7ED)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: Colors.black38, size: 20),
        ],
      ),
    );
  }
}

class StoreActionPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final String? onTapRoute;

  const StoreActionPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.onTapRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3E7ED)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: StorePalette.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: FilledButton(
                    onPressed: onTapRoute == null
                        ? null
                        : () => Navigator.of(context).pushNamed(onTapRoute!),
                    style: FilledButton.styleFrom(
                      backgroundColor: StorePalette.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE7EBF1),
                      disabledForegroundColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StoreSearchStrip extends StatelessWidget {
  final VoidCallback onTap;

  const StoreSearchStrip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3E7ED)),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.search, color: Colors.black54, size: 20),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Search this store',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreProductThumb extends StatelessWidget {
  final String asset;
  final double size;

  const StoreProductThumb({
    super.key,
    required this.asset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 180,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFFEAF5FF),
          child: const Icon(LucideIcons.image, color: Color(0xFF078D92)),
        ),
      ),
    );
  }
}

class StoreOrderNumberText extends StatelessWidget {
  final String text;

  const StoreOrderNumberText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = text.split('#');
    if (parts.length < 2) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF060D35),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF060D35),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
        children: [
          TextSpan(text: '${parts.first}#'),
          TextSpan(
            text: parts.sublist(1).join('#'),
            style: const TextStyle(color: Color(0xFF684AC8)),
          ),
        ],
      ),
    );
  }
}
