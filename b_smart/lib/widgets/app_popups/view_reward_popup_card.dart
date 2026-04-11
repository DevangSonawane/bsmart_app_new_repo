import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ViewRewardPopupCard extends StatelessWidget {
  final int amount;
  final VoidCallback onOk;
  final String subtitle;

  const ViewRewardPopupCard({
    super.key,
    required this.amount,
    required this.onOk,
    this.subtitle = 'Earned for watching the full ad',
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFFDE68A);
    const pillTextColor = Color(0xFFD97706);
    const circleGradient = LinearGradient(
      colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const buttonGradient = LinearGradient(
      colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 30,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: circleGradient,
                ),
                child: const Icon(LucideIcons.coins,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                '+$amount Coins',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: pillTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: buttonGradient,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 14,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: onOk,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Awesome!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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

