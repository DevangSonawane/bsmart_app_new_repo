import 'package:flutter/material.dart';

class ViewRecordedPopupCard extends StatelessWidget {
  final int? viewCount;
  final VoidCallback onOk;

  const ViewRecordedPopupCard({
    super.key,
    required this.viewCount,
    required this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E7EB);
    const circleGradient = LinearGradient(
      colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const buttonGradient = LinearGradient(
      colors: [Color(0xFF6B7280), Color(0xFF374151)],
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
                child: const Icon(
                  Icons.remove_red_eye,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'View Recorded',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (viewCount != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Total views: $viewCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'No coins rewarded for this view',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
                      'Got it',
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

