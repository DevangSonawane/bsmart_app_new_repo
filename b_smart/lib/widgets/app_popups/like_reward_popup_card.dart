import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LikeRewardPopupCard extends StatelessWidget {
  final int amount;
  final bool isLike;
  final VoidCallback onOk;

  const LikeRewardPopupCard({
    super.key,
    required this.amount,
    required this.isLike,
    required this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isLike ? const Color(0xFFFCA5A5) : const Color(0xFFD1D5DB);
    final pillTextColor =
        isLike ? const Color(0xFFEF4444) : const Color(0xFF6B7280);
    final circleGradient = isLike
        ? const LinearGradient(
            colors: [Color(0xFFFB7185), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final buttonGradient = isLike
        ? const LinearGradient(
            colors: [Color(0xFFFB7185), Color(0xFFEC4899)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF9CA3AF), Color(0xFF4B5563)],
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
            color: Colors.white.withValues(alpha: 0.94),
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: circleGradient,
                ),
                child: Icon(
                  isLike ? Icons.favorite : LucideIcons.circleX,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isLike ? '+$amount Coins' : '-$amount Coins',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pillTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isLike ? 'Thanks for liking!' : 'Dislike recorded',
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
                    child: Text(
                      isLike ? 'Nice!' : 'Okay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

